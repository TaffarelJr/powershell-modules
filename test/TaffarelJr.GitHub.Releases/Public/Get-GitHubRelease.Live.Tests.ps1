#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Releases/TaffarelJr.GitHub.Releases.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the real gh against a public repository with many releases
$releases = Get-GitHubRelease -List -Limit 2 -Repository 'cli/cli'

# Assert
Assert-Equal -Expected 2 -Actual $releases.Count -Message 'The live listing honors -Limit'
Assert-That -Condition ($releases[0].TagName -like 'v*') -Message 'A listed release carries its tag'
Assert-That `
    -Condition ($releases[0].PSObject.Properties.Name -contains 'IsLatest') `
    -Message 'A list-only field is present as a PascalCase property'
Assert-Equal `
    -Expected 'cli/cli' `
    -Actual $releases[0].Repository `
    -Message 'A listed release carries the repository it was listed from'

#───────────────────────────────────────────────────────────────────────────────
# Act - the latest release in full
$latest = Get-GitHubRelease -Repository 'cli/cli'

# Assert
Assert-That -Condition ($latest.TagName -like 'v*') -Message 'The latest release is described'
Assert-That -Condition ($latest.Assets.Count -gt 0) -Message 'The latest release carries its assets'
Assert-That `
    -Condition (-not [string]::IsNullOrEmpty($latest.Assets[0].Name)) `
    -Message 'An asset is re-cased with its name intact'
Assert-That -Condition ($latest.IsImmutable -is [bool]) -Message 'The view''s isImmutable field exists'

#───────────────────────────────────────────────────────────────────────────────
# Act - chosen fields, named as the result spells them
$chosen = Get-GitHubRelease -Repository 'cli/cli' -Property 'TagName', 'Url'

# Assert
Assert-Equal `
    -Expected @('TagName', 'Url', 'Repository') `
    -Actual @($chosen.PSObject.Properties.Name) `
    -Message 'PascalCase field names are accepted by the real gh'

#───────────────────────────────────────────────────────────────────────────────
# Act - the listed releases piped back in to be described in full
$described = @($releases | Get-GitHubRelease -Repository 'cli/cli')

# Assert
Assert-Equal `
    -Expected @($releases.ForEach('TagName')) `
    -Actual @($described.ForEach('TagName')) `
    -Message 'Each listed release piped back in is described by its TagName'

exit (Complete-TestRun)
