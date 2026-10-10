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
$fake = New-FakeGitHubCli
try {
    # Act
    Connect-GitHubAccount -Token 'ghp_secret'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'login', '--with-token') -Actual $call.Arguments -Message 'gh is told to read the token from standard input'
    Assert-Equal -Expected 'ghp_secret' -Actual $call.StdIn -Message 'The token is what gets piped'
    Assert-That -Condition ($call.Arguments -notcontains 'ghp_secret') -Message 'The token never appears among the arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every option
$fake = New-FakeGitHubCli
try {
    # Act
    Connect-GitHubAccount -Token 't' -Hostname 'ghe.example' -GitProtocol https -Scopes @('write:org', 'read:public_key') -InsecureStorage
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'login', '--with-token', '--hostname', 'ghe.example', '--git-protocol', 'https', '--scopes', 'write:org', '--scopes', 'read:public_key', '--insecure-storage') -Actual $call.Arguments -Message 'Each option becomes its gh flag, one --scopes per scope'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
