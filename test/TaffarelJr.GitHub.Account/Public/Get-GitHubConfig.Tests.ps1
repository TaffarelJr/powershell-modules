#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one setting by name
$fake = New-FakeGitHubCli -Output @('ssh')
try {
    # Act
    $value = Get-GitHubConfig -Name 'git_protocol' -Hostname 'github.com'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('config', 'get', 'git_protocol', '--host', 'github.com') -Actual $call.Arguments -Message '-Name asks gh for that one setting'
    Assert-Equal -Expected 'ssh' -Actual $value -Message 'The value is returned as a string'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every setting, parsed from key=value lines
$fake = New-FakeGitHubCli -Output @('git_protocol=https', 'editor=', 'pager=less')
try {
    # Act
    $settings = Get-GitHubConfig
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('config', 'list') -Actual $call.Arguments -Message 'Without -Name, every setting is listed'
    Assert-Equal -Expected 3 -Actual $settings.Count -Message 'Every key=value line becomes one object, including a blank value'
    Assert-Equal -Expected 'git_protocol' -Actual $settings[0].Name -Message 'The key before = becomes Name'
    Assert-Equal -Expected 'https' -Actual $settings[0].Value -Message 'The text after = becomes Value'
    Assert-Equal -Expected '' -Actual $settings[1].Value -Message 'A blank value is kept as an empty string, not dropped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
