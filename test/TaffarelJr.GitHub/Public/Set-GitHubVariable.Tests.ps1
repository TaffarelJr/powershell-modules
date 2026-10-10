#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository variable
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubVariable -Name 'CI_LANGUAGES' -Value 'dotnet,powershell' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'set', 'CI_LANGUAGES', '--repo', 'o/r') -Actual $call.Arguments -Message 'Only the name and repository are arguments'
    Assert-Equal -Expected 'dotnet,powershell' -Actual $call.StdIn -Message 'The value reaches gh on standard input'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an organization variable limited to some repositories
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubVariable -Name 'V' -Value 'x' -Environment 'prod' -Organization 'org' -Visibility selected -Repos @('a', 'b')
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'set', 'V', '--env', 'prod', '--org', 'org', '--visibility', 'selected', '--repos', 'a,b') -Actual $call.Arguments -Message 'Scope options become their gh flags, repositories comma-joined'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an empty value, which is legitimate for a variable
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubVariable -Name 'EMPTY' -Value ''
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'An empty value is accepted and piped as empty'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - many variables from a dotenv file
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubVariable -EnvFile '.env'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'set', '--env-file', '.env') -Actual $call.Arguments -Message '-EnvFile replaces the name with gh''s --env-file'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
