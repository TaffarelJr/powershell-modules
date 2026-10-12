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
# Arrange - a named repository
$fake = New-FakeGitHubCli -Output @('[{"type":"copilot_code_review","ruleset_id":123}]')
try {
    # Act
    $rules = Get-GitHubRulesetCheck -Branch 'main' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r/rules/branches/main') -Actual $call.Arguments -Message 'The repository and branch are embedded directly in the endpoint path'
    Assert-Equal -Expected 123 -Actual $rules[0].RulesetId -Message 'Each applying rule is parsed and re-cased'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current directory's repository, no applying rules at all
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $rules = 'main' | Get-GitHubRulesetCheck
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/{owner}/{repo}/rules/branches/main') -Actual $call.Arguments -Message 'The branch binds from the pipeline, and without -Repository the ambient-repo placeholder is used'
    Assert-Equal -Expected 0 -Actual $rules.Count -Message 'No applying rules is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
