#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    Write-Host 'skipped - gh has no working login here'
    exit (Complete-TestRun)
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a real search against GitHub, narrowed to one well-known owner
$repos = Find-GitHubRepository -Owner @('cli') -Limit 3

# Assert
Assert-Equal -Expected 3 -Actual $repos.Count -Message 'The live search honors -Limit'
Assert-That -Condition (-not [string]::IsNullOrEmpty($repos[0].FullName)) -Message 'A result carries its full name'
Assert-That -Condition ($repos[0].PSObject.Properties.Name -contains 'StargazersCount') -Message 'A requested field is present as a PascalCase property'

exit (Complete-TestRun)
