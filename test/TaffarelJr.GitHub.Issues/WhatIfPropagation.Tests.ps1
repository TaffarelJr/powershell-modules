#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$cases = @(
    @{ Name = 'Add-GitHubIssueComment'; Call = { Add-GitHubIssueComment -Issue 12 -Body 'b' -Repository 'o/r' } }
    @{ Name = 'Close-GitHubIssue'; Call = { Close-GitHubIssue -Issue 12 -Repository 'o/r' } }
    @{ Name = 'Lock-GitHubIssue'; Call = { Lock-GitHubIssue -Issue 12 -Repository 'o/r' } }
    @{
        Name = 'Move-GitHubIssue'
        Call = { Move-GitHubIssue -Issue 12 -DestinationRepository 'o/other' -Repository 'o/r' }
    }
    @{ Name = 'New-GitHubIssue'; Call = { New-GitHubIssue -Title 't' -Body 'b' -Repository 'o/r' } }
    @{ Name = 'Open-GitHubIssue'; Call = { Open-GitHubIssue -Issue 12 -Repository 'o/r' } }
    @{ Name = 'Remove-GitHubIssue'; Call = { Remove-GitHubIssue -Issue 12 -Repository 'o/r' } }
    @{ Name = 'Set-GitHubIssue'; Call = { Set-GitHubIssue -Issue 12 -Title 't' -Repository 'o/r' } }
    @{ Name = 'Unlock-GitHubIssue'; Call = { Unlock-GitHubIssue -Issue 12 -Repository 'o/r' } }
)

foreach ($case in $cases) {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function run with -WhatIf, calling the command that changes things
    $fake = New-FakeGitHubCli
    try {
        # Act
        $whatIf = Get-WhatIfOutput -ScriptBlock { Invoke-WhatIfCaller -Call $case.Call -WhatIf }
        $calls = @(Get-FakeGitHubCall -Fixture $fake)

        # Assert
        Assert-Equal -Expected 1 -Actual $whatIf.Messages.Count `
            -Message "$($case.Name) reaches its guard under its caller's -WhatIf, and says what it would do"
        Assert-Equal -Expected 0 -Actual $calls.Count -Message 'and changes nothing: gh is never called'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

exit (Complete-TestRun)
