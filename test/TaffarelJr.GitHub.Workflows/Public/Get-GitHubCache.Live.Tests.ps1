#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

# Caches expire, so a repository may have none right now, and then there is
# nothing to check the fields of
$caches = @(Get-GitHubCache -Limit 5 -Repository 'cli/cli')
if ($caches.Count -eq 0) {
    exit (Skip-TestRun -Reason 'the repository has no caches right now')
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the first cache the live repository lists
$cache = $caches[0]

# Assert
Assert-That -Condition (-not [string]::IsNullOrEmpty($cache.Key)) -Message 'A returned cache carries its key'
Assert-That -Condition ($cache.Id -gt 0) -Message 'and a numeric Id, which is what deleting one by object reads'
Assert-That -Condition ($cache.SizeInBytes -gt 0) -Message 'and its size, re-cased from size_in_bytes'

exit (Complete-TestRun)
