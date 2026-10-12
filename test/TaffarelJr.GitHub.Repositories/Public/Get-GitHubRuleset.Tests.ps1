#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one ruleset in full, from a named repository
$fake = New-FakeGitHubCli -Output @('{"id":123,"name":"Main","enforcement":"active","conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"]}}}')
try {
    # Act
    $ruleset = Get-GitHubRuleset -Id 123 -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/rulesets/123') -Actual $call.Arguments -Message 'A named repository is embedded directly in the endpoint path, not passed as --repo'
    Assert-Equal -Expected 'Main' -Actual $ruleset.Name -Message 'The ruleset comes back as one object with PascalCase fields'
    Assert-Equal -Expected @('~DEFAULT_BRANCH') -Actual $ruleset.Conditions.RefName.Include -Message 'Nested conditions are re-cased too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current directory's repository, via the ambient-repo placeholder
$fake = New-FakeGitHubCli -Output @('{"id":1}')
try {
    # Act
    Get-GitHubRuleset -Id 1 | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/{owner}/{repo}/rulesets/1') -Actual $call.Arguments -Message 'Without -Repository, gh''s own {owner}/{repo} placeholder is used'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing a repository's rulesets, including inherited ones
$fake = New-FakeGitHubCli -Output @('[{"id":1,"name":"A"},{"id":2,"name":"B"}]')
try {
    # Act
    $rulesets = Get-GitHubRuleset -List -IncludeParents -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/rulesets?includes_parents=true') -Actual $call.Arguments -Message '-IncludeParents adds the query string'
    Assert-Equal -Expected 2 -Actual $rulesets.Count -Message 'Every listed ruleset is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - organization-scoped, single listed ruleset
$fake = New-FakeGitHubCli -Output @('[{"id":9}]')
try {
    # Act
    $rulesets = Get-GitHubRuleset -List -Organization 'TaffarelJr'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'orgs/TaffarelJr/rulesets') -Actual $call.Arguments -Message '-Organization scopes to the org endpoint instead of a repository'
    Assert-That -Condition ($rulesets -is [array]) -Message 'A single listed ruleset is still returned as an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
