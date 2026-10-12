#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') `
    -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'bucket,completedAt,description,event,link,name,startedAt,state,workflow'
$passed = '[{"name":"build","state":"SUCCESS","bucket":"pass"}]'
$pending = '[{"name":"build","state":"SUCCESS","bucket":"pass"},{"name":"deploy","state":"PENDING","bucket":"pending"}]'
$failing = '[{"name":"test","state":"FAILURE","bucket":"fail"},{"name":"deploy","state":"PENDING","bucket":"pending"}]'
$noChecks = @{ ErrorOutput = @('no checks reported on the ''feature'' branch'); ExitCode = 1 }
$badGateway = @{ ErrorOutput = @('HTTP 502: Bad Gateway'); ExitCode = 1 }

# Every wait polls on a clock that moves only when the wait sleeps, and the
# sleep only records how long it would have been.
$clock = Use-FakePollClock -Module $module

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every check passed
$fake = New-FakeGitHubCli -Output @($passed)
try {
    # Act
    $checks = Get-GitHubPullRequestCheck -PullRequest 12 -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'checks', '12', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The checks are asked for as JSON with a fixed field set'
    Assert-That -Condition ($checks -isnot [array]) `
        -Message 'A single check is written as that one object, not wrapped in an array'
    Assert-Equal -Expected 'pass' -Actual $checks.Bucket -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failed check and a pending one, which gh prints with exit 0
$fake = New-FakeGitHubCli -Output @($failing)
try {
    # Act
    $checks = @(Get-GitHubPullRequestCheck -Required)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('pr', 'checks', '--json', $fields, '--required') -Actual $calls[0].Arguments `
        -Message '-Required becomes --required'
    Assert-Equal -Expected 1 -Actual $calls.Count -Message 'Without -Wait, the checks are read once'
    Assert-Equal -Expected @('fail', 'pending') -Actual @($checks.Bucket) `
        -Message 'Failing and pending checks are returned for the caller to judge, not thrown'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failure that produced no checks at all, which gh reports on standard error
$fake = New-FakeGitHubCli -ErrorOutput @('no pull requests found for branch "x"') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 'x'
    } -MessageLike "Reading the checks of pull request x failed: gh pr checks x --json $fields (exit 1)`nno pull requests found for branch `"x`"" `
        -Message 'A failure throws with the arguments and the message from gh, as every other function does'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pull request that has no checks, which is an answer and not a failure
$fake = New-FakeGitHubCli @noChecks
try {
    # Act
    $checks = @(Get-GitHubPullRequestCheck -PullRequest 12)

    # Assert
    Assert-Equal -Expected 0 -Actual $checks.Count `
        -Message 'No checks reported returns nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pull request with no required checks
$fake = New-FakeGitHubCli -ErrorOutput @('no required checks reported on the ''feature'' branch') -ExitCode 1
try {
    # Act
    $checks = @(Get-GitHubPullRequestCheck -PullRequest 12 -Required)

    # Assert
    Assert-Equal -Expected 0 -Actual $checks.Count -Message 'No required checks reported returns nothing too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a branch whose name reads like gh's "no checks" answer, and a real failure
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 500: Server Error') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 'no-checks-reported'
    } -MessageLike "*no-checks-reported*`nHTTP 500: Server Error" `
        -Message 'Only gh''s own text is read for "no checks reported", never the arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh succeeds and prints nothing
$fake = New-FakeGitHubCli
try {
    # Act
    $checks = @(Get-GitHubPullRequestCheck -PullRequest 12)

    # Assert
    Assert-Equal -Expected 0 -Actual $checks.Count `
        -Message 'A call that succeeds with nothing to show is no checks, not a failure'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - output that is not checks, with a non-zero exit
$fake = New-FakeGitHubCli -Output @('something else entirely') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 12
    } -MessageLike '*checks of pull request 12 failed: gh pr checks 12 *(exit 1)*something else entirely*' `
        -Message 'A non-zero exit is a failure, its output quoted'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - output that is not JSON, with exit 0
$fake = New-FakeGitHubCli -Output @('something else entirely')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 12
    } -MessageLike "*gh's output is not valid JSON*" `
        -Message 'Output that is not JSON throws rather than reading as no checks'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a check still pending, then finished
$fake = New-FakeGitHubCli -Sequence @(@{ Output = @($pending) }, @{ Output = @($passed) })
$clock.Slept.Clear()
try {
    # Act
    $checks = @(Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 1)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message '-Wait reads the checks again while one is pending'
    Assert-Equal -Expected @('pr', 'checks', '12', '--json', $fields) -Actual $calls[1].Arguments `
        -Message 'with the same call each time'
    Assert-Equal -Expected @(1000) -Actual @($clock.Slept) -Message 'sleeping -PollSeconds between the reads'
    Assert-Equal -Expected @('pass') -Actual @($checks.Bucket) -Message 'and returns the checks once none is pending'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - waiting with the default interval
$fake = New-FakeGitHubCli -Sequence @(@{ Output = @($pending) }, @{ Output = @($passed) })
$clock.Slept.Clear()
try {
    # Act
    Get-GitHubPullRequestCheck -PullRequest 12 -Wait | Out-Null

    # Assert
    Assert-Equal -Expected @(5000) -Actual @($clock.Slept) `
        -Message 'The default interval is 5 seconds, as for Wait-GitHubWorkflowRun'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failed check while another is still pending
$fake = New-FakeGitHubCli -Sequence @(@{ Output = @($failing) }, @{ Output = @($passed) })
try {
    # Act
    $checks = @(Get-GitHubPullRequestCheck -PullRequest 12 -Wait -FailFast -PollSeconds 1)
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 1 -Actual $calls.Count -Message '-FailFast stops waiting at the first failed check'
    Assert-Equal -Expected @('fail', 'pending') -Actual @($checks.Bucket) `
        -Message 'and returns the checks as they stood'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a check that stays pending
$fake = New-FakeGitHubCli -Output @($pending)
$clock.Slept.Clear()
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 1 -TimeoutSeconds 3
    } -ExceptionType ([System.TimeoutException]) `
        -MessageLike 'The checks of pull request 12 were still pending after 3 s: deploy. Give a longer -TimeoutSeconds to wait more.' `
        -Message 'Running out of time throws a TimeoutException, naming what is still pending'
    Assert-Equal -Expected 4 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'after a last read at the deadline itself'
    Assert-Equal -Expected @(1000, 1000, 1000) -Actual @($clock.Slept) -Message 'and never sleeping past it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an interval longer than the whole wait
$fake = New-FakeGitHubCli -Output @($pending)
$clock.Slept.Clear()
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 30 -TimeoutSeconds 1
    } -ExceptionType ([System.TimeoutException]) -MessageLike '*still pending after 1 s*' `
        -Message 'A long interval still ends at the timeout'
    Assert-Equal -Expected @(1000) -Actual @($clock.Slept) `
        -Message 'as the sleep is cut to the time left, not a whole -PollSeconds'
    Assert-Equal -Expected 2 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and the last read comes at the deadline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no checks reported yet, just after a push, then pending, then passed
$fake = New-FakeGitHubCli -Sequence @($noChecks, @{ Output = @($pending) }, @{ Output = @($passed) })
try {
    # Act
    $checks = @(Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 1)

    # Assert
    Assert-Equal -Expected 3 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'No checks reported yet is waited on, not taken for no checks at all'
    Assert-Equal -Expected @('pass') -Actual @($checks.Bucket) -Message 'and the checks are returned once they finish'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - empty output, then passed
$fake = New-FakeGitHubCli -Sequence @(@{ Output = @() }, @{ Output = @($passed) })
try {
    # Act
    $checks = @(Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 1)

    # Assert
    Assert-Equal -Expected @('pass') -Actual @($checks.Bucket) `
        -Message 'Empty output is waited on like no checks reported'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - pending, then no checks reported until the deadline
$fake = New-FakeGitHubCli -Sequence @(@{ Output = @($pending) }, $noChecks)
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 1 -TimeoutSeconds 2
    } -ExceptionType ([System.TimeoutException]) `
        -MessageLike 'No checks of pull request 12 were reported within 2 s. Give a longer -TimeoutSeconds to wait more.' `
        -Message 'Checks that vanish mid-wait, as after a force-push, are waited on until the timeout, which says none were reported'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no required checks reported at all
$fake = New-FakeGitHubCli -ErrorOutput @('no required checks reported on the ''feature'' branch') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 12 -Required -Wait -PollSeconds 1 -TimeoutSeconds 1
    } -ExceptionType ([System.TimeoutException]) `
        -MessageLike 'No checks of pull request 12 were reported within 1 s.*' `
        -Message 'With -Required, no required checks reported is waited on the same way'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failed read of every kind, each the first answer gh gives
$failures = @(
    @{
        Printed  = 'HTTP 403: API rate limit exceeded for user ID 1. (https://api.github.com/graphql)'
        ExitCode = 1
        Code     = 'HTTP 403'
    }
    @{
        Printed  = 'HTTP 404: Not Found (https://api.github.com/graphql)'
        ExitCode = 1
        Code     = 'HTTP 404'
    }
    @{
        Printed  = 'HTTP 429: Too Many Requests, retry after 7 seconds'
        ExitCode = 1
        Code     = 'HTTP 429'
    }
    @{
        Printed  = 'HTTP 500: Server Error'
        ExitCode = 1
        Code     = 'HTTP 500'
    }
    @{
        Printed  = 'HTTP 401: Bad credentials'
        ExitCode = 1
        Code     = 'HTTP 401'
    }
    @{
        Printed  = 'GraphQL: API rate limit already exceeded for user ID 1.'
        ExitCode = 1
        Code     = 'exit 1'
    }
)
foreach ($failure in $failures) {
    $clock.Slept.Clear()
    $fake = New-FakeGitHubCli -Sequence @(@{ ErrorOutput = @($failure.Printed); ExitCode = $failure.ExitCode })
    $expected = "Could not read the checks of pull request 12 ($($failure.Code)):`n$($failure.Printed)"
    try {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 30 -TimeoutSeconds 600
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
# Arrange - pending twice, then a gateway error in mid-wait
$fake = New-FakeGitHubCli -Sequence @(@{ Output = @($pending) }, @{ Output = @($pending) }, $badGateway)
$clock.Slept.Clear()
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 2 -TimeoutSeconds 600
    } -MessageLike "Could not read the checks of pull request 12 (HTTP 502):`nHTTP 502: Bad Gateway" `
        -Message 'A failed read after good ones ends the wait too'

    # Assert
    Assert-Equal -Expected 3 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'Good reads keep the wait polling, up to the failed one'
    Assert-Equal -Expected @(2000, 2000) -Actual @($clock.Slept) -Message 'with a pause after each good read only'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pull request gh cannot find, while waiting
$fake = New-FakeGitHubCli -ErrorOutput @('no pull requests found for branch "x"') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 'x' -Wait -PollSeconds 1
    } -MessageLike "Could not read the checks of pull request x (exit 1):`nno pull requests found for branch `"x`"" `
        -Message 'No such pull request throws at once too'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'so gh is asked once'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a check gh lists without a bucket, then passed
$fake = New-FakeGitHubCli -Sequence @(@{ Output = @('[{"name":"a"}]') }, @{ Output = @($passed) })
try {
    # Act
    $checks = @(Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 1)

    # Assert
    Assert-Equal -Expected 2 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'A check without a bucket counts as pending, so the wait goes on'
    Assert-Equal -Expected @('pass') -Actual @($checks.Bucket) -Message 'and the checks are returned once they finish'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a check whose bucket is only spaces, then a null element, then passed
$fake = New-FakeGitHubCli -Sequence @(
    @{ Output = @('[{"name":"a","bucket":"  "}]') }
    @{ Output = @('[null]') }
    @{ Output = @($passed) }
)
try {
    # Act
    $checks = @(Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 1)

    # Assert
    Assert-Equal -Expected 3 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'A blank bucket counts as pending, and a null element as no check, so the wait goes on'
    Assert-Equal -Expected @('pass') -Actual @($checks.Bucket) -Message 'and the checks are returned once they finish'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - checks without a bucket until the deadline, one of them without a name
$fake = New-FakeGitHubCli -Output @('[{"name":"a"},{}]')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 1 -TimeoutSeconds 1
    } -ExceptionType ([System.TimeoutException]) `
        -MessageLike 'The checks of pull request 12 were still pending after 1 s: a, (no name). Give a longer -TimeoutSeconds to wait more.' `
        -Message 'Checks without a bucket are named as pending at the deadline, not thrown on'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - pending checks whose names hold an @, one of them after a colon
$fake = New-FakeGitHubCli -Output @('[{"name":"build (node@18)"},{"name":"ci: lint@2"}]')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 1 -TimeoutSeconds 1
    } -ExceptionType ([System.TimeoutException]) `
        -MessageLike ([WildcardPattern]::Escape(
            'The checks of pull request 12 were still pending after 1 s: build (node@18), ***@2.' +
            ' Give a longer -TimeoutSeconds to wait more.')) `
        -Message 'An @ in one check name hides only that name, never the words before it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failed read of several lines
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 502: Bad Gateway', 'upstream timed out') -ExitCode 1
$expected = "Could not read the checks of pull request 12 (HTTP 502):`nHTTP 502: Bad Gateway`nupstream timed out"
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PullRequest 12 -Wait -PollSeconds 1 -TimeoutSeconds 1
    } -MessageLike $expected `
        -Message 'gh''s reason over several lines keeps each line'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - waiting options without -Wait, and an interval that asks for nothing
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -PollSeconds 5
    } -MessageLike '-PollSeconds, -TimeoutSeconds, and -FailFast work only with -Wait: they shape the wait. Give -Wait too, or leave them off.' `
        -Message 'A waiting option without -Wait is refused, not ignored'
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -FailFast
    } -MessageLike '-PollSeconds, -TimeoutSeconds, and -FailFast work only with -Wait: they shape the wait. Give -Wait too, or leave them off.' `
        -Message 'and so is -FailFast'
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -TimeoutSeconds 9 -Wait:$false
    } -MessageLike '-PollSeconds, -TimeoutSeconds, and -FailFast work only with -Wait: they shape the wait. Give -Wait too, or leave them off.' `
        -Message 'and so is a waiting option with -Wait:$false'
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestCheck -Wait -PollSeconds 0
    } -MessageLike "*'PollSeconds'*minimum allowed range of 1*" -Message 'An interval below 1 is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -Wait:$false alone
$fake = New-FakeGitHubCli -Output @($pending)
try {
    # Act
    $checks = @(Get-GitHubPullRequestCheck -PullRequest 12 -Wait:$false)

    # Assert
    Assert-Equal -Expected @('pass', 'pending') -Actual @($checks.Bucket) `
        -Message '-Wait:$false reads the checks once, as without -Wait'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
