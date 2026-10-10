#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    Write-Host 'skipped - gh has no working login here'
    exit (Complete-TestRun)
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the real gh against a public repository with many releases
$releases = Get-GitHubRelease -List -Limit 2 -Repository 'cli/cli'

# Assert
Assert-Equal -Expected 2 -Actual $releases.Count -Message 'The live listing honors -Limit'
Assert-That -Condition ($releases[0].TagName -like 'v*') -Message 'A listed release carries its tag'
Assert-That -Condition ($releases[0].PSObject.Properties.Name -contains 'IsLatest') -Message 'A list-only field is present as a PascalCase property'

#───────────────────────────────────────────────────────────────────────────────
# Act - the latest release in full
$latest = Get-GitHubRelease -Repository 'cli/cli'

# Assert
Assert-That -Condition ($latest.TagName -like 'v*') -Message 'The latest release is described'
Assert-That -Condition ($latest.Assets.Count -gt 0) -Message 'The latest release carries its assets'
Assert-That -Condition (-not [string]::IsNullOrEmpty($latest.Assets[0].Name)) -Message 'An asset is re-cased with its name intact'

exit (Complete-TestRun)
