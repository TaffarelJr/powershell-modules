#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') `
    -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

# Every wait here runs on a fake clock that moves only when the wait sleeps,
# so the polls and pauses asserted do not depend on this machine's speed.
$clock = Use-FakePollClock -Module $module

$fields = 'attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,name,number,' +
'startedAt,status,updatedAt,url,workflowDatabaseId,workflowName,jobs'
$running = @{ Output = @('{"status":"in_progress"}') }
$done = @{ Output = @('{"status":"completed"}') }

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the run is already completed on the very first poll,
# so the wait returns before ever sleeping
$clock.Slept.Clear()
$fake = New-FakeGitHubCli -Output @('{"databaseId":123,"status":"completed","conclusion":"success"}')
try {
    # Act
    $run = Wait-GitHubWorkflowRun -RunId 123 -Repository 'o/r'
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'The run is polled once, then read back in full'
    Assert-Equal -Expected @('run', 'view', '123', '--json', 'status', '--repo', 'o/r') -Actual $calls[0].Arguments `
        -Message 'The poll asks only for status'
    Assert-Equal -Expected @('run', 'view', '123', '--json', $fields, '--repo', 'o/r') -Actual $calls[1].Arguments `
        -Message 'The finished run is read back with its jobs'
    Assert-Equal -Expected 'success' -Actual $run.Conclusion -Message 'The finished run is returned'
    Assert-Equal -Expected 0 -Actual $clock.Slept.Count -Message 'without sleeping'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the run is in progress on the first poll and completed on the next
$clock.Slept.Clear()
$final = @{ Output = @('{"databaseId":7,"status":"completed","conclusion":"success"}') }
$fake = New-FakeGitHubCli -Sequence @($running, $done, $final)
try {
    # Act
    $run = Wait-GitHubWorkflowRun -RunId 7 -PollSeconds 2
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 3 -Actual $calls.Count `
        -Message 'A run still in progress is polled again, and stops being polled once completed'
    Assert-Equal -Expected @(2000) -Actual @($clock.Slept) -Message 'after one poll interval'
    Assert-Equal -Expected 'success' -Actual $run.Conclusion -Message 'and the run is returned as it finished'
    Assert-Equal -Expected @('run', 'view', '7', '--json', $fields) -Actual $calls[2].Arguments `
        -Message 'A run of the current directory''s repository is read back with no --repo'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - runs that finish without succeeding
$endings = @('cancelled', 'skipped', 'failure')
foreach ($ending in $endings) {
    $final = @{ Output = @("{`"databaseId`":7,`"status`":`"completed`",`"conclusion`":`"$ending`"}") }
    $fake = New-FakeGitHubCli -Sequence @($running, $done, $final)
    try {
        # Act
        $run = Wait-GitHubWorkflowRun -RunId 7 -PollSeconds 1

        # Assert
        Assert-Equal -Expected 'completed' -Actual $run.Status -Message "A $ending run ends the wait as completed"
        Assert-Equal -Expected $ending -Actual $run.Conclusion -Message "with its $ending conclusion, not thrown"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the run never leaves in_progress, and the timeout is far shorter
# than the poll interval
$clock.Slept.Clear()
$fake = New-FakeGitHubCli -Output @('{"databaseId":7,"status":"in_progress"}')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRun -RunId 7 -TimeoutSeconds 1 -PollSeconds 30
    } -ExceptionType ([TimeoutException]) `
        -MessageLike ('Workflow run 7 was still in_progress after 1 s.' +
            ' Give a longer -TimeoutSeconds to wait more.') `
        -Message 'A run still running at the deadline throws a TimeoutException naming its last status'

    # Assert
    Assert-Equal -Expected @(1000) -Actual @($clock.Slept) `
        -Message 'The wait sleeps until the timeout, not a poll interval longer'
    Assert-Equal -Expected 2 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and reads the run once more at the deadline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the run completes during the last interval before the deadline
$final = @{ Output = @('{"databaseId":7,"status":"completed","conclusion":"success"}') }
$fake = New-FakeGitHubCli -Sequence @($running, $done, $final)
try {
    # Act
    $run = Wait-GitHubWorkflowRun -RunId 7 -TimeoutSeconds 1 -PollSeconds 5

    # Assert
    Assert-Equal -Expected 'success' -Actual $run.Conclusion `
        -Message 'The poll at the deadline finds a run that finished in the last interval'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh answers every poll with nothing at all
$fake = New-FakeGitHubCli -Output @()
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRun -RunId 7 -TimeoutSeconds 2 -PollSeconds 1
    } -ExceptionType ([TimeoutException]) `
        -MessageLike 'Workflow run 7 had no status after 2 s. Give a longer -TimeoutSeconds to wait more.' `
        -Message 'An empty answer is a poll with no status, waited out to the deadline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh answers every poll with a run that has no status field
$fake = New-FakeGitHubCli -Output @('{"conclusion":"x"}')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRun -RunId 7 -TimeoutSeconds 2 -PollSeconds 1
    } -ExceptionType ([TimeoutException]) `
        -MessageLike 'Workflow run 7 had no status after 2 s. Give a longer -TimeoutSeconds to wait more.' `
        -Message 'An answer without a status field is a poll with no status, not a StrictMode error'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the fake clock takes exactly the parameters Core's New-GitHubPoll
# takes
$poll = & $module { New-GitHubPoll -TimeoutSeconds 9 -PollSeconds 2 }

# Act / Assert
Assert-Equal -Expected @(([TimeSpan]::FromSeconds(9)), 2) -Actual @($poll.Timeout, $poll.PollSeconds) `
    -Message 'The fake clock passes every parameter on to Core''s New-GitHubPoll'
Assert-Throws -ScriptBlock {
    & $module { New-GitHubPoll -TimeoutSeconds 9 -PollSeconds 2 -Unknown 1 }
} -MessageLike "*parameter name 'Unknown'*" -Message 'and refuses one Core does not know'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failed read of every kind, each the first answer gh gives; gh
# run view puts the status after its own words, and the lead names it either way
$failures = @(
    @{
        Printed  = 'failed to get run: HTTP 403: API rate limit exceeded for user ID 1. (https://api.github.com/...)'
        ExitCode = 1
        Kind     = 'HTTP 403'
        Code     = 'HTTP 403'
    }
    @{
        Printed  = 'failed to get run: HTTP 404: Not Found (https://api.github.com/...)'
        ExitCode = 1
        Kind     = 'HTTP 404'
        Code     = 'HTTP 404'
    }
    @{
        Printed  = 'failed to get run: HTTP 429: Too Many Requests (https://api.github.com/...)'
        ExitCode = 1
        Kind     = 'HTTP 429'
        Code     = 'HTTP 429'
    }
    @{
        Printed  = 'failed to get run: HTTP 500: Internal Server Error (https://api.github.com/...)'
        ExitCode = 1
        Kind     = 'HTTP 500'
        Code     = 'HTTP 500'
    }
    @{
        Printed  = 'HTTP 503: Service Unavailable (https://api.github.com/...)'
        ExitCode = 1
        Kind     = 'a status at the start of the line'
        Code     = 'HTTP 503'
    }
    @{
        Printed  = 'To get started with GitHub CLI, please run:  gh auth login'
        ExitCode = 4
        Kind     = 'no login'
        Code     = 'exit 4'
    }
)
foreach ($failure in $failures) {
    $clock.Slept.Clear()
    $fake = New-FakeGitHubCli -Sequence @(@{ ErrorOutput = @($failure.Printed); ExitCode = $failure.ExitCode })
    $expected = "Could not read workflow run 9 ($($failure.Code)):`n$($failure.Printed)"
    try {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            Wait-GitHubWorkflowRun -RunId 9 -TimeoutSeconds 600 -PollSeconds 30
        } -MessageLike ([WildcardPattern]::Escape($expected)) `
            -Message "A failed read ($($failure.Kind)) throws at once, with gh's output"

        # Assert
        Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
            -Message "after the first read, never asking again ($($failure.Kind))"
        Assert-Equal -Expected 0 -Actual $clock.Slept.Count -Message "and without sleeping ($($failure.Kind))"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two good reads of a run still going, then a failed one
$printed = 'failed to get run: HTTP 502: Bad Gateway (https://api.github.com/...)'
$failed = @{ ErrorOutput = @($printed); ExitCode = 1 }
$expected = "Could not read workflow run 9 (HTTP 502):`n$printed"
$clock.Slept.Clear()
$fake = New-FakeGitHubCli -Sequence @($running, $running, $failed, $done)
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRun -RunId 9 -TimeoutSeconds 600 -PollSeconds 3
    } -MessageLike ([WildcardPattern]::Escape($expected)) `
        -Message 'A failed read after good ones ends the wait too'

    # Assert
    Assert-Equal -Expected 3 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'Good reads keep the wait polling, up to the failed one'
    Assert-Equal -Expected @(3000, 3000) -Actual @($clock.Slept) -Message 'with a pause after each good read only'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
