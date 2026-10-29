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

$secret = 'SENTINEL_SECRET_123'
$settings = @('git_protocol=https', 'editor=', 'pager=')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that lists its settings, and then refuses the value, quoting it
$fake = New-FakeGitHubCli -Sequence @(
    @{ Output = $settings }
    @{ ErrorOutput = @("gh: invalid value $secret for editor"); ExitCode = 1 }
)
try {
    # Act
    $refused = Get-GitHubCallOutcome { Set-GitHubConfig -Name 'editor' -Value $secret -Verbose }
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    $hiddenMessage = "Setting config editor failed: gh config set -- editor *** (exit 1)" +
    "`ngh: invalid value *** for editor"
    Assert-Equal -Expected $hiddenMessage -Actual $refused.Message `
        -Message 'A value is hidden in the command line and the lines of the failure message'
    Assert-Equal -Expected $refused.Message -Actual $refused.Target `
        -Message 'and in the error''s target, which is that message'
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $refused -Text $secret) `
        -Message 'and in the error as PowerShell renders it, Get-Error, $Error[0], and every verbose line'
    Assert-That -Condition ($refused.Verbose -contains 'Setting config editor: gh config set -- editor ***') `
        -Message 'The verbose line of the write shows *** in place of the value'
    Assert-Equal -Expected @('config', 'set', '--', 'editor', $secret) -Actual $calls[1].Arguments `
        -Message 'while gh is still given the value as it was'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that accepts the value
$fake = New-FakeGitHubCli -Output $settings
try {
    # Act
    $accepted = Get-GitHubCallOutcome { Set-GitHubConfig -Name 'editor' -Value $secret -Verbose }
    $whatIf = Get-WhatIfOutput { Set-GitHubConfig -Name 'editor' -Value $secret -WhatIf }

    # Assert
    Assert-Equal -Expected @() -Actual @(Get-LeakingSurface -Outcome $accepted -Text $secret) `
        -Message 'A value that is accepted appears in no verbose line either'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match $secret) -Message '-WhatIf never shows it'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
