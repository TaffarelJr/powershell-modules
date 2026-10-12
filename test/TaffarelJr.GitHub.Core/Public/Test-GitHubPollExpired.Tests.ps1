#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
#───────────────────────────────────────────────────────────────────────────────
# Arrange
$poll = New-GitHubPoll -TimeoutSeconds 60 -PollSeconds 5
$ends = @(
    @{ Elapsed = 0; Expected = $false; Message = 'A fresh wait has not expired' }
    @{ Elapsed = 59.9; Expected = $false; Message = 'nor one just short of its timeout' }
    @{ Elapsed = 60; Expected = $true; Message = 'A wait at its timeout has expired' }
    @{ Elapsed = 90; Expected = $true; Message = 'and so has one past it' }
)

# Act / Assert
foreach ($case in $ends) {
    $poll.Clock = [PSCustomObject]@{ Elapsed = [TimeSpan]::FromSeconds($case.Elapsed) }
    Assert-Equal -Expected $case.Expected -Actual (Test-GitHubPollExpired -Poll $poll) -Message $case.Message
}

exit (Complete-TestRun)
