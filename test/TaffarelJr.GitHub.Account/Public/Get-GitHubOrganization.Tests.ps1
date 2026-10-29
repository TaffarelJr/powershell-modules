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
# Arrange - two pages, as gh's --slurp gathers them
$fake = New-FakeGitHubCli -Output @('[[{"login":"TaffarelJr","id":1}],[{"login":"other","id":2}]]')
try {
    # Act
    $orgs = @(Get-GitHubOrganization)
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'user/orgs?per_page=100', '--paginate', '--slurp') -Actual $call.Arguments `
        -Message 'Every page is asked for, with no --repo, since orgs are user-level, and no --hostname'
    Assert-Equal -Expected @('TaffarelJr', 'other') -Actual @($orgs.Login) `
        -Message 'The organizations of every page are returned, with PascalCase field names'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one organization
$fake = New-FakeGitHubCli -Output @('[[{"login":"TaffarelJr","id":1}]]')
try {
    # Act / Assert
    Assert-That -Condition ((Get-GitHubOrganization) -isnot [array]) `
        -Message 'A single organization is written as that one object, not wrapped in an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no organizations
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act
    $orgs = @(Get-GitHubOrganization)

    # Assert
    Assert-Equal -Expected 0 -Actual $orgs.Count `
        -Message 'No organizations writes nothing, so @() collects an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the login of another host
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act
    Get-GitHubOrganization -Hostname 'ghe.example' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @('api', 'user/orgs?per_page=100', '--paginate', '--slurp', '--hostname', 'ghe.example')
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message '-Hostname asks that host''s API, for the account gh is logged in to there'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a paging switch, and a host by position
$fake = New-FakeGitHubCli -Output @('[[]]')
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubOrganization -All
    } -MessageLike "*parameter cannot be found*'All'*" -Message 'There is no -All: every page is always read'
    Assert-Throws -ScriptBlock {
        Get-GitHubOrganization 'ghe.example'
    } -MessageLike '*positional parameter cannot be found*' -Message 'and the host is never positional'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'with gh never called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}
#───────────────────────────────────────────────────────────────────────────────
# Arrange - a token that may not list organizations
$fake = New-FakeGitHubCli -ErrorOutput @('gh: Resource not accessible by personal access token (HTTP 403)') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubOrganization
    } -MessageLike '*Calling user/orgs?per_page=100 failed*(HTTP 403)*' `
        -Message 'A refused call throws with gh''s reason'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
