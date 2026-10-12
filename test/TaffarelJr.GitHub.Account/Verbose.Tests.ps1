#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot 'GitHubAccountTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a reader that runs gh, called with its own -Verbose
$fake = New-FakeGitHubCli -Output @('editor=vim')
try {
    # Act
    $outcome = Get-GitHubCallOutcome { Get-GitHubConfig -Verbose }

    # Assert
    Assert-Equal -Expected @('Listing config: gh config list') -Actual $outcome.Verbose `
        -Message 'A call given -Verbose prints the command line it runs'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same reader, called from a function whose $VerbosePreference is Continue
$fake = New-FakeGitHubCli -Output @('editor=vim')
try {
    # Act
    $outcome = Get-GitHubCallOutcome { Invoke-VerboseCaller { Get-GitHubConfig } }

    # Assert
    Assert-Equal -Expected @('Listing config: gh config list') -Actual $outcome.Verbose `
        -Message 'A call from a function that set $VerbosePreference prints the command line too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same caller, and a call that turns -Verbose off for itself
$fake = New-FakeGitHubCli -Output @('editor=vim')
try {
    # Act
    $outcome = Get-GitHubCallOutcome { Invoke-VerboseCaller { Get-GitHubConfig -Verbose:$false } }

    # Assert
    Assert-Equal -Expected @() -Actual $outcome.Verbose `
        -Message 'A call given -Verbose:$false prints nothing, whatever its caller prefers'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
