#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'PublicSurfaceTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - the manifest, the exports, their help, and a test for every function
Test-ModulePublicSurface -Module 'TaffarelJr.Tally'

exit (Complete-TestRun)
