#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('gho_abc123')
try {
    # Act
    $token = Get-GitHubToken
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'token') -Actual $call.Arguments -Message 'The active account on the default host is asked for'
    Assert-Equal -Expected 'gho_abc123' -Actual $token -Message 'The token line is returned as a string'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a specific host and account
$fake = New-FakeGitHubCli -Output @('gho_other')
try {
    # Act
    Get-GitHubToken -Hostname 'ghe.example' -User 'me' | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'token', '--hostname', 'ghe.example', '--user', 'me') -Actual $call.Arguments -Message '-Hostname and -User become their gh flags'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
