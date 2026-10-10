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
# Act - the real gh against a public repository
$labels = Get-GitHubLabel -Limit 3 -Sort name -Repository 'cli/cli'

# Assert
Assert-Equal -Expected 3 -Actual $labels.Count -Message 'The live listing honors -Limit'
Assert-That -Condition (-not [string]::IsNullOrEmpty($labels[0].Name)) -Message 'A listed label carries its name'
Assert-That -Condition ($labels[0].Color -match '^[0-9A-Fa-f]{6}$') -Message 'A listed label carries its six-digit color'

exit (Complete-TestRun)
