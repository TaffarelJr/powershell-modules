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

$old = @{ Output = @('[{"databaseId":30},{"databaseId":20},{"databaseId":10}]') }

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the very first poll already lists a run newer than -Before,
# so the wait returns before ever sleeping
$clock.Slept.Clear()
$fake = New-FakeGitHubCli -Output @('[{"databaseId":9},{"databaseId":5}]')
try {
    # Act
    $id = Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @(5) -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected ([long]9) -Actual $id -Message 'The id of the run newer than -Before is returned'
    $expected = @(
        'run', 'list', '--workflow', 'ci.yml', '--event', 'workflow_dispatch'
        '--limit', '20', '--json', 'databaseId', '--repo', 'o/r'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'gh is asked only for the workflow''s dispatched runs'
    Assert-Equal -Expected 0 -Actual $clock.Slept.Count -Message 'without sleeping'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -Before from a listing of one run (the newest), and a listing
# whose older runs are not in -Before; nothing new until the second poll
$clock.Slept.Clear()
$fake = New-FakeGitHubCli -Sequence @($old, @{ Output = @('[{"databaseId":40},{"databaseId":30},{"databaseId":20}]') })
try {
    # Act
    $id = Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @([PSCustomObject]@{ DatabaseId = 30 }) -PollSeconds 2
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected ([long]40) -Actual $id `
        -Message 'Only a run newer than every -Before run counts, so older runs outside -Before are not taken'
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'and a run that appears on the second poll is found there'
    Assert-Equal -Expected @(2000) -Actual @($clock.Slept) -Message 'one poll interval later'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two new runs at once, and -Before as ids and listing objects mixed
$fake = New-FakeGitHubCli -Output @('[{"databaseId":41},{"databaseId":42},{"databaseId":30}]')
try {
    # Act
    $before = @(30, '25', @{ databaseId = 20 }, [PSCustomObject]@{ DatabaseId = [long]10 })
    $id = Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before $before

    # Assert
    Assert-Equal -Expected ([long]42) -Actual $id `
        -Message 'The newest new run is returned, whatever order gh lists them in'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a 19-digit run id, which a [long] holds
$fake = New-FakeGitHubCli -Output @('[{"databaseId":1000000000000000001},{"databaseId":1000000000000000000}]')
try {
    # Act
    $id = Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @('1000000000000000000')

    # Assert
    Assert-Equal -Expected ([long]1000000000000000001) -Actual $id `
        -Message 'A -Before id of 19 digits is read as a run id'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a workflow that had no runs before the dispatch
$empty = @(
    @{ Before = @(); Message = 'An empty -Before' }
    @{ Before = $null; Message = 'A $null -Before, which a listing of no runs gives outside StrictMode' }
    @{ Before = @($null); Message = 'A -Before holding only $null' }
)
foreach ($case in $empty) {
    $fake = New-FakeGitHubCli -Output @('[{"databaseId":3}]')
    try {
        # Act
        $id = Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before $case.Before

        # Assert
        Assert-Equal -Expected ([long]3) -Actual $id -Message "$($case.Message) takes any run as new"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a ref, and a workflow object
$fake = New-FakeGitHubCli -Output @('[{"databaseId":9}]')
try {
    # Act
    $workflow = [PSCustomObject]@{ Id = 132478870; Path = 'dynamic/dependabot/dependabot-updates' }
    Wait-GitHubWorkflowRunStart -Workflow $workflow -Before @(5) -Ref 'release/1.0' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'run', 'list', '--workflow', '132478870', '--event', 'workflow_dispatch'
        '--branch=release/1.0', '--limit', '20', '--json', 'databaseId'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'A workflow object is named by its Id, and -Ref narrows the listing to its branch'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a workflow listed from another repository, as Start-GitHubWorkflow
# dispatches it there, and -Before runs listed there
$fake = New-FakeGitHubCli -Output @('[{"databaseId":9}]')
try {
    $workflow = [PSCustomObject]@{ Id = 9; Path = '.github/workflows/ci.yml'; Repository = 'o/r' }
    $listed = [PSCustomObject]@{ DatabaseId = 5; Url = 'https://github.com/o/r/actions/runs/5'; Repository = 'o/r' }
    $urlOnly = [PSCustomObject]@{ DatabaseId = 5; Url = 'https://github.com/o/r/actions/runs/5' }

    # Act
    Wait-GitHubWorkflowRunStart -Workflow $workflow -Before @(1) | Out-Null
    Wait-GitHubWorkflowRunStart -Workflow $workflow -Before @(1) -Repository 'github.com/O/R' | Out-Null
    Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @($listed) | Out-Null
    Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @($urlOnly) | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('--repo', 'o/r') -Actual @($calls[0].Arguments[-2..-1]) `
        -Message 'A workflow object''s runs are polled in the repository it came from'
    Assert-Equal -Expected @('--repo', 'github.com/O/R') -Actual @($calls[1].Arguments[-2..-1]) `
        -Message 'and a -Repository naming the same repository another way is used'
    Assert-Equal -Expected @('--repo', 'o/r') -Actual @($calls[2].Arguments[-2..-1]) `
        -Message 'A workflow by name is polled where the -Before runs were listed'
    Assert-Equal -Expected @('--repo', 'https://github.com/o/r') -Actual @($calls[3].Arguments[-2..-1]) `
        -Message 'or where a -Before run''s Url says it is'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a -Repository, or -Before runs, naming another repository than
# the workflow's
$fake = New-FakeGitHubCli -Output @('[{"databaseId":9}]')
try {
    $workflow = [PSCustomObject]@{ Id = 9; Path = '.github/workflows/ci.yml'; Repository = 'o/r' }
    $elsewhere = [PSCustomObject]@{ DatabaseId = 5; Repository = 'x/y' }
    $here = [PSCustomObject]@{ DatabaseId = 4; Url = 'https://github.com/o/r/actions/runs/4' }

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow $workflow -Before @() -Repository 'x/y'
    } -MessageLike 'Workflow 9 is in o/r, but -Repository names x/y: give one or the other.' `
        -Message 'A -Repository naming another repository than the workflow''s throws'
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow $workflow -Before @($elsewhere)
    } -MessageLike ('Run 5 in -Before is in x/y, but workflow 9 is in o/r:' +
        " list -Before from the workflow's repository.") `
        -Message 'A -Before run listed from another repository than the workflow''s throws, naming the workflow'
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @($elsewhere) -Repository 'o/r'
    } -MessageLike 'Run 5 in -Before is in x/y, but -Repository names o/r: give one or the other.' `
        -Message 'and one from another repository than -Repository names it'
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @($here, $elsewhere)
    } -MessageLike 'Run 5 in -Before is in x/y, but run 4 in -Before is in o/r: list -Before from one repository.' `
        -Message 'A workflow by name with -Before runs from two repositories throws, naming both runs'

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every poll succeeds, but never with a new run, and the timeout
# is far shorter than the poll interval
$clock.Slept.Clear()
$fake = New-FakeGitHubCli -Sequence @($old)
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @(30) -TimeoutSeconds 1 -PollSeconds 30
    } -ExceptionType ([TimeoutException]) `
        -MessageLike ("No new workflow_dispatch run of 'ci.yml' appeared within 1 s." +
            ' Give a longer -TimeoutSeconds to wait more.') `
        -Message 'No new run within the timeout throws a TimeoutException naming the workflow'

    # Assert
    Assert-Equal -Expected @(1000) -Actual @($clock.Slept) -Message 'at the timeout, not a poll interval later'
    Assert-Equal -Expected 2 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'after listing the runs once more at the deadline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh lists an element with no databaseId
$fake = New-FakeGitHubCli -Sequence @(@{ Output = @('[{}]') }, @{ Output = @('[{},{"databaseId":12}]') })
try {
    # Act
    $id = Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @() -TimeoutSeconds 5 -PollSeconds 1

    # Assert
    Assert-Equal -Expected ([long]12) -Actual $id `
        -Message 'A listed element with no databaseId is passed over, not a crash'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the run appears during the last interval before the deadline
$fake = New-FakeGitHubCli -Sequence @(@{ Output = @('[]') }, @{ Output = @('[{"databaseId":11}]') })
try {
    # Act
    $id = Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @() -TimeoutSeconds 1 -PollSeconds 5

    # Assert
    Assert-Equal -Expected ([long]11) -Actual $id `
        -Message 'The poll at the deadline finds a run that appeared in the last interval'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failed read of every kind, each the first answer gh gives
$failures = @(
    @{
        Printed  = 'HTTP 403: API rate limit exceeded for user ID 1. (https://api.github.com/...)'
        ExitCode = 1
        Code     = 'HTTP 403'
    }
    @{
        Printed  = 'HTTP 404: workflow nope.yml not found on the default branch (https://api.github.com/...)'
        ExitCode = 1
        Code     = 'HTTP 404'
    }
    @{
        Printed  = 'HTTP 429: You have exceeded a secondary rate limit. (https://api.github.com/...)'
        ExitCode = 1
        Code     = 'HTTP 429'
    }
    @{
        Printed  = 'HTTP 500: Server Error (https://api.github.com/...)'
        ExitCode = 1
        Code     = 'HTTP 500'
    }
    @{
        Printed  = 'could not find any workflows named nope.yml'
        ExitCode = 1
        Code     = 'exit 1'
    }
)
foreach ($failure in $failures) {
    $clock.Slept.Clear()
    $fake = New-FakeGitHubCli -Sequence @(@{ ErrorOutput = @($failure.Printed); ExitCode = $failure.ExitCode })
    $expected = "Could not list the workflow_dispatch runs of 'nope.yml' ($($failure.Code)):`n$($failure.Printed)"
    try {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            Wait-GitHubWorkflowRunStart -Workflow 'nope.yml' -Before @() -TimeoutSeconds 600 -PollSeconds 30
        } -MessageLike ([WildcardPattern]::Escape($expected)) `
            -Message "A failed read ($($failure.Code)) throws at once, with gh's output"

        # Assert
        Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
            -Message "after the first read, never asking again ($($failure.Code))"
        Assert-Equal -Expected 0 -Actual $clock.Slept.Count -Message "and without sleeping ($($failure.Code))"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two good listings with nothing new, then a failed one
$printed = 'HTTP 502: Bad Gateway (https://api.github.com/...)'
$failed = @{ ErrorOutput = @($printed); ExitCode = 1 }
$expected = "Could not list the workflow_dispatch runs of 'ci.yml' (HTTP 502):`n$printed"
$clock.Slept.Clear()
$fake = New-FakeGitHubCli -Sequence @($old, $old, $failed, @{ Output = @('[{"databaseId":31}]') })
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @(30) -TimeoutSeconds 600 -PollSeconds 3
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

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -Before values that are no run, and other values that name nothing
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @('abc')
    } -MessageLike "'abc' in -Before is not a run id: give the runs*" -Message 'Text that is not a number is refused'
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @(0)
    } -MessageLike "'0' in -Before is not a run id: give the runs*" -Message 'as is 0, which no run has'
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @('-5')
    } -MessageLike "'-5' in -Before is not a run id: give the runs*" -Message 'and a negative id'
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @('99999999999999999999')
    } -MessageLike "'99999999999999999999' in -Before is not a run id: give the runs*" `
        -Message 'and one too large for a run id'
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @([PSCustomObject]@{ Id = 5 })
    } -MessageLike 'A run in -Before needs a DatabaseId, and this one has none: PSCustomObject.' `
        -Message 'An object with no DatabaseId is refused - a workflow''s or cache''s Id is not a run id'
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow $null -Before @()
    } -MessageLike "*parameter 'Workflow' because it is null*" -Message 'A $null workflow is refused'
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow @('a.yml', 'b.yml') -Before @()
    } -MessageLike 'Give one workflow at a time, not a list of 2; call once per workflow.' `
        -Message 'A list of workflows is refused, with advice to call once per workflow'
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @() -Ref ''
    } -MessageLike '-Ref was given but is blank, so it would filter nothing. Give a value, or leave -Ref off.' `
        -Message 'A blank -Ref is refused, not taken for every ref'
    Assert-Throws -ScriptBlock {
        Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @() -Repository $null
    } -MessageLike '-Repository was given, but it is $null - leave it out to use*' `
        -Message 'A -Repository given as $null is refused'

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
