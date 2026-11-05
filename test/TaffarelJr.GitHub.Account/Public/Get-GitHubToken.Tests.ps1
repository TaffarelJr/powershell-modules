#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Account/TaffarelJr.GitHub.Account.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('gho_abc123')
try {
    # Act
    $token = Get-GitHubToken
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'token') -Actual $call.Arguments `
        -Message 'The active account on the default host is asked for'
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
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'token', '--hostname', 'ghe.example', '--user', 'me') -Actual $call.Arguments `
        -Message '-Hostname and -User become their gh flags'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the account named by position, as Switch- and Disconnect-GitHubAccount take it
$fake = New-FakeGitHubCli -Output @('gho_other')
try {
    # Act
    Get-GitHubToken 'me' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'token', '--user', 'me') -Actual $call.Arguments `
        -Message 'The first positional value is the account, not the host'
    Assert-Throws -ScriptBlock {
        Get-GitHubToken 'me' 'ghe.example'
    } -MessageLike '*positional parameter cannot be found*' -Message 'and the host is never positional'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a gh that succeeds but prints nothing
$fake = New-FakeGitHubCli -Output @()
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubToken
    } -MessageLike 'Reading the authentication token failed: gh exited 0 but printed no token.' `
        -Message 'No token printed throws, rather than returning nothing or failing on an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a host gh holds no token for
$fake = New-FakeGitHubCli -ErrorOutput @('no oauth token found for ghe.example') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubToken -Hostname 'ghe.example'
    } -MessageLike '*Reading the authentication token failed*no oauth token found for ghe.example*' `
        -Message 'A missing token throws with gh''s reason'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
