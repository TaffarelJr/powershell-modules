#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository secret
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubSecret -Name 'NUGET_KEY' -Value 'hunter2' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'set', 'NUGET_KEY', '--repo', 'o/r') -Actual $call.Arguments -Message 'Only the name and repository are arguments'
    Assert-Equal -Expected 'hunter2' -Actual $call.StdIn -Message 'The value reaches gh on standard input'
    Assert-That -Condition ($call.Arguments -notcontains 'hunter2') -Message 'The value never appears among the arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an organization secret limited to some repositories
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubSecret -Name 'TOKEN' -Value 'v' -Organization 'org' -Visibility selected -Repos @('a', 'b') -Application actions
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'set', 'TOKEN', '--org', 'org', '--app', 'actions', '--visibility', 'selected', '--repos', 'a,b') -Actual $call.Arguments -Message 'Organization options become their gh flags, repositories comma-joined'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the remaining scope options
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubSecret -Name 'S' -Value 'v' -Environment 'prod' -User -NoReposSelected
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'set', 'S', '--env', 'prod', '--user', '--no-repos-selected') -Actual $call.Arguments -Message 'Environment, user, and no-repos-selected become their gh flags'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - many secrets from a dotenv file
$fake = New-FakeGitHubCli
try {
    # Act
    Set-GitHubSecret -EnvFile '.env' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'set', '--env-file', '.env', '--repo', 'o/r') -Actual $call.Arguments -Message '-EnvFile replaces the name with gh''s --env-file'
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'Nothing is piped when the values come from a file'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
