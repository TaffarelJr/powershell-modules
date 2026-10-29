#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a merge commit and a commit that is not one, from a real repository
$merge = @(Find-GitHubCommit -Repository 'cli/cli' -Merge -Limit 1)
$plain = @(Find-GitHubCommit -Repository 'cli/cli' -Merge:$false -Limit 1)

# Assert
Assert-Equal -Expected 1 -Actual $merge.Count -Message 'The live search honors -Limit'
Assert-Equal -Expected 1 -Actual $plain.Count -Message 'and finds a commit that is not a merge'
Assert-That -Condition (($merge | ForEach-Object Sha) -match '^[0-9a-f]{40}$') -Message 'A result carries its sha'
Assert-Equal -Expected 2 -Actual @($merge | ForEach-Object Parents).Count `
    -Message '-Merge finds a commit with two parents'
Assert-Equal -Expected 1 -Actual @($plain | ForEach-Object Parents).Count `
    -Message 'and -Merge:$false one with a single parent, so the false form reaches gh as a filter'

exit (Complete-TestRun)
