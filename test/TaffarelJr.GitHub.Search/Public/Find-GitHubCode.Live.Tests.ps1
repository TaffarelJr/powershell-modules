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
# Act - a real code search by filters alone, with no query
$results = @(Find-GitHubCode -Repository 'cli/cli' -Filename 'shared.go' -Limit 1)

# Assert
Assert-Equal -Expected 1 -Actual $results.Count -Message 'The live search honors -Limit, with filters alone'
Assert-That -Condition (($results | ForEach-Object Path) -like '*shared.go') `
    -Message 'A result carries its path, and the filename filter reached gh'
Assert-Equal -Expected 'cli/cli' -Actual ($results | ForEach-Object Repository | ForEach-Object NameWithOwner) `
    -Message 'and its repository, which is the one asked for'
Assert-That -Condition (@($results | ForEach-Object { $_.PSObject.Properties.Name }) -contains 'TextMatches') `
    -Message 'Every requested field is present, as gh accepted the whole list'

exit (Complete-TestRun)
