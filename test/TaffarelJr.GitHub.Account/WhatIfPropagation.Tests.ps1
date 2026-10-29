#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

# Reads is how many gh calls the function makes before its guard, to check what to change.
$cases = @(
    @{ Name = 'Clear-GitHubConfigCache'; Call = { Clear-GitHubConfigCache }; Reads = 0 }
    @{ Name = 'Connect-GitHubAccount'; Call = { Connect-GitHubAccount -Token 'SENTINEL_TOKEN_123' }; Reads = 0 }
    @{ Name = 'Disconnect-GitHubAccount'; Call = { Disconnect-GitHubAccount -User 'me' }; Reads = 0 }
    @{ Name = 'Register-GitHubCredentialHelper'; Call = { Register-GitHubCredentialHelper }; Reads = 0 }
    @{ Name = 'Set-GitHubConfig'; Call = { Set-GitHubConfig -Name 'editor' -Value 'vim' }; Reads = 1 }
    @{ Name = 'Switch-GitHubAccount'; Call = { Switch-GitHubAccount -User 'me' }; Reads = 0 }
)

foreach ($case in $cases) {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a function run with -WhatIf, calling the command that changes things
    $fake = New-FakeGitHubCli -Output @('editor=vim')
    try {
        # Act
        $whatIf = Get-WhatIfOutput -ScriptBlock { Invoke-WhatIfCaller -Call $case.Call -WhatIf }
        $calls = @(Get-FakeGitHubCall -Fixture $fake)

        # Assert
        Assert-Equal -Expected 1 -Actual $whatIf.Messages.Count `
            -Message "$($case.Name) reaches its guard under its caller's -WhatIf, and says what it would do"
        Assert-Equal -Expected $case.Reads -Actual $calls.Count `
            -Message 'and changes nothing: gh is asked only for what the guard needs'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

exit (Complete-TestRun)
