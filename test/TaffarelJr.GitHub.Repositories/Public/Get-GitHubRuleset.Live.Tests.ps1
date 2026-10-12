#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Repositories/TaffarelJr.GitHub.Repositories.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    Write-Host 'skipped - gh has no working login here'
    exit (Complete-TestRun)
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the real GitHub REST API, against a public repository known to carry
# at least one ruleset
$rulesets = Get-GitHubRuleset -List -Repository 'cli/cli'

# Assert
Assert-That -Condition ($rulesets.Count -gt 0) -Message 'The live repository has at least one ruleset'
Assert-That -Condition ($rulesets[0].Id -gt 0) -Message 'A listed ruleset carries its id'
Assert-That -Condition (-not [string]::IsNullOrEmpty($rulesets[0].Name)) -Message 'A listed ruleset carries its name'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same ruleset in full
$ruleset = Get-GitHubRuleset -Id $rulesets[0].Id -Repository 'cli/cli'

# Assert
Assert-Equal -Expected $rulesets[0].Id -Actual $ruleset.Id -Message 'A ruleset described by id is the one asked for'
Assert-That -Condition ($ruleset.PSObject.Properties.Name -contains 'Rules') -Message 'The full view carries the Rules field the list view omits'

exit (Complete-TestRun)
