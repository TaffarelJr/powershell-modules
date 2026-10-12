#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    Write-Host 'skipped - gh has no working login here'
    exit (Complete-TestRun)
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the real gh against a public repository with heavy Actions use;
# caches expire, so the count itself is not asserted, only the shape
$caches = Get-GitHubCache -Limit 5 -Repository 'cli/cli'

# Assert
Assert-That -Condition ($caches -is [array]) -Message 'The live call returns an array, with or without caches present'
if ($caches.Count -gt 0) {
    Assert-That -Condition (-not [string]::IsNullOrEmpty($caches[0].Key)) -Message 'A returned cache carries its key'
}

exit (Complete-TestRun)
