#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Act
$good = @(Assert-GitHubPollRead -Result @{ Ok = $true; ExitCode = 0; Message = '' } -Action 'read workflow run 9')

# Assert
Assert-Equal -Expected 0 -Actual $good.Count -Message 'A good read passes and returns nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every kind of failed read, each of which ends the wait at once
$failures = @(
    @{
        ExitCode = 1
        Printed = 'HTTP 403: Resource not accessible by integration (https://api.github.com/repos/o/r)'
        Code = 'HTTP 403'
        Message = 'A 403 throws at once'
    }
    @{
        ExitCode = 1
        Printed = 'HTTP 403: API rate limit exceeded for user ID 1. (https://api.github.com/repos/o/r)'
        Code = 'HTTP 403'
        Message = 'and so does a rate limit, which is not waited out'
    }
    @{
        ExitCode = 1
        Printed = 'HTTP 429: Too Many Requests - retry after 30 seconds'
        Code = 'HTTP 429'
        Message = 'even one that says how long to wait'
    }
    @{
        ExitCode = 1
        Printed = 'GraphQL: API rate limit already exceeded for user ID 12345.'
        Code = 'exit 1'
        Message = 'A GraphQL rate limit, which carries no status, gives gh''s exit code'
    }
    @{
        ExitCode = 1
        Printed = 'HTTP 502: Bad Gateway (https://api.github.com/repos/o/r)'
        Code = 'HTTP 502'
        Message = 'A server error is not tolerated'
    }
    @{
        ExitCode = 1
        Printed = 'error connecting to api.github.com'
        Code = 'exit 1'
        Message = 'and nor is a network failure'
    }
    @{
        ExitCode = 1
        Printed = 'gh: Not Found (HTTP 404)'
        Code = 'HTTP 404'
        Message = 'gh api''s own form of the status is read too'
    }
    @{
        ExitCode = 1
        Printed = 'gh: HTTP 401'
        Code = 'HTTP 401'
        Message = 'and its bare one'
    }
    @{
        ExitCode = 4
        Printed = 'To get started with GitHub CLI, please run:  gh auth login'
        Code = 'exit 4'
        Message = 'No login throws with gh''s exit code'
    }
    @{
        ExitCode = 1
        Printed = "warning: slow`nHTTP 503: Service Unavailable (https://api.github.com/repos/o/r)"
        Code = 'HTTP 503'
        Message = 'A status on a later line is found, and every line is kept'
    }
)

# Act / Assert
foreach ($failure in $failures) {
    $result = @{ Ok = $false; ExitCode = $failure.ExitCode; Message = $failure.Printed }
    $expected = "Could not read workflow run 9 ($($failure.Code)):`n$($failure.Printed)"
    Assert-Throws -ScriptBlock {
        Assert-GitHubPollRead -Result $result -Action 'read workflow run 9'
    } -MessageLike ([WildcardPattern]::Escape($expected)) -Message $failure.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a failure that printed nothing
Assert-Throws -ScriptBlock {
    Assert-GitHubPollRead -Result @{ Ok = $false; ExitCode = 7; Message = ' ' } -Action 'read x'
} -MessageLike 'Could not read x (exit 7): gh printed nothing.' `
    -Message 'The message names the exit code and says gh printed nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a credential in the action and in what gh printed
$result = @{
    Ok = $false
    ExitCode = 1
    Message = "fatal: could not read https://u:SENTINEL@ghe.example.com/o/r`n" +
    'HTTP 404: Not Found (https://ghe.example.com/api/v3/repos/o/r)'
}
$expected = "Could not read the runs of https://***@ghe.example.com/o/r (HTTP 404):`n" +
"fatal: could not read https://***@ghe.example.com/o/r`n" +
'HTTP 404: Not Found (https://ghe.example.com/api/v3/repos/o/r)'

# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-GitHubPollRead -Result $result -Action 'read the runs of https://u:SENTINEL@ghe.example.com/o/r'
} -MessageLike ([WildcardPattern]::Escape($expected)) `
    -Message 'Every credential is hidden, in the action and on each line gh printed'

exit (Complete-TestRun)
