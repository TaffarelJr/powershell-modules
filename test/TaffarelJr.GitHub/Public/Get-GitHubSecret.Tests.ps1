#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$fields = 'name,numSelectedRepos,selectedReposURL,updatedAt,visibility'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository's secrets
$fake = New-FakeGitHubCli -Output @('[{"name":"NUGET_KEY","updatedAt":"2026-01-02T03:04:05Z","visibility":"private"}]')
try {
    # Act
    $secrets = Get-GitHubSecret -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'list', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message 'The repository is passed as --repo with a fixed field set'
    Assert-That -Condition ($secrets -is [array]) -Message 'A single secret is still returned as an array'
    Assert-Equal -Expected 'NUGET_KEY' -Actual $secrets[0].Name -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every scope option
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $secrets = Get-GitHubSecret -Environment 'prod' -Organization 'org' -User -Application dependabot
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('secret', 'list', '--json', $fields, '--env', 'prod', '--org', 'org', '--user', '--app', 'dependabot') -Actual $call.Arguments -Message 'Each scope option becomes its gh flag'
    Assert-Equal -Expected 0 -Actual $secrets.Count -Message 'No secrets is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
