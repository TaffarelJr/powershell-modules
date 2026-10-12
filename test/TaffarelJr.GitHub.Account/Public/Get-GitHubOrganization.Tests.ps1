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
# Arrange
$fake = New-FakeGitHubCli -Output @('[{"login":"TaffarelJr","id":1}]')
try {
    # Act
    $orgs = Get-GitHubOrganization
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'user/orgs') -Actual $call.Arguments -Message 'The endpoint is called with no --repo, since orgs are user-level'
    Assert-That -Condition ($orgs -is [array]) -Message 'A single organization is still returned as an array'
    Assert-Equal -Expected 'TaffarelJr' -Actual $orgs[0].Login -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every organization, paginated
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $orgs = Get-GitHubOrganization -All
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'user/orgs', '--paginate', '--slurp') -Actual $call.Arguments -Message '-All asks for every page'
    Assert-Equal -Expected 0 -Actual $orgs.Count -Message 'No organizations is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
