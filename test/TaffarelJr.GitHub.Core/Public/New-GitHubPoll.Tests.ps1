#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
#───────────────────────────────────────────────────────────────────────────────
# Act
$poll = New-GitHubPoll -TimeoutSeconds 90 -PollSeconds 5
$keys = @($poll.Keys | Sort-Object)

# Assert
Assert-That -Condition ($poll.Clock -is [System.Diagnostics.Stopwatch] -and $poll.Clock.IsRunning) `
    -Message 'A poll starts a running Stopwatch'
Assert-Equal -Expected @([TimeSpan]::FromSeconds(90), 5) -Actual @($poll.Timeout, $poll.PollSeconds) `
    -Message 'with its timeout and interval'
Assert-That -Condition ($poll.Sleep -is [scriptblock]) -Message 'and Sleep is a script block a test can replace'
Assert-Equal -Expected @('Clock', 'PollSeconds', 'Sleep', 'Timeout') -Actual $keys `
    -Message 'and nothing else: a failed read ends the wait, so there is no failure state to keep'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a failure count is not a setting any more
Assert-Throws -ScriptBlock {
    New-GitHubPoll -TimeoutSeconds 5 -PollSeconds 1 -MaxTransientFailures 3
} -MessageLike "*A parameter cannot be found that matches parameter name 'MaxTransientFailures'*" `
    -Message 'No count of tolerated failures is taken'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - values outside the ranges
Assert-Throws -ScriptBlock {
    New-GitHubPoll -TimeoutSeconds 0 -PollSeconds 5
} -MessageLike '*TimeoutSeconds*' -Message 'A timeout of 0 is refused'
Assert-Throws -ScriptBlock {
    New-GitHubPoll -TimeoutSeconds 5 -PollSeconds 3601
} -MessageLike '*PollSeconds*' -Message 'and so is an interval over an hour'

exit (Complete-TestRun)
