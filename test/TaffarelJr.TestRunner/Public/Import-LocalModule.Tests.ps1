#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder with both a manifest and its own sibling .psm1
$manifestModuleFolder = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $manifestModuleFolder -Force | Out-Null
"function Get-ManifestModuleMarker { 'manifest' }`nExport-ModuleMember -Function Get-ManifestModuleMarker" |
    Set-Content -LiteralPath (Join-Path $manifestModuleFolder 'ModuleWithManifest.psm1')
"@{ RootModule = 'ModuleWithManifest.psm1'; ModuleVersion = '1.0.0' }" |
    Set-Content -LiteralPath (Join-Path $manifestModuleFolder 'ModuleWithManifest.psd1')

# Act
Import-LocalModule -Path $manifestModuleFolder

# Assert
Assert-Equal -Expected 'manifest' -Actual (Get-ManifestModuleMarker) -Message 'A manifest-rooted folder is imported by its .psd1'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder with only a bare .psm1, no manifest at all, plus a loose
# .ps1 alongside it that must never be touched
$bareModuleFolder = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $bareModuleFolder -Force | Out-Null
"function Get-BareModuleMarker { 'bare' }`nExport-ModuleMember -Function Get-BareModuleMarker" |
    Set-Content -LiteralPath (Join-Path $bareModuleFolder 'BareModuleHelpers.psm1')
"throw 'Invoke-Something was executed - Import-LocalModule must never touch a bare .ps1'" |
    Set-Content -LiteralPath (Join-Path $bareModuleFolder 'Invoke-Something.ps1')

# Act
Import-LocalModule -Path $bareModuleFolder

# Assert
Assert-Equal -Expected 'bare' -Actual (Get-BareModuleMarker) -Message 'A folder with no manifest is imported by its bare .psm1'
Assert-That -Condition (-not (Get-Command -Name 'Invoke-Something' -ErrorAction SilentlyContinue)) -Message 'A loose .ps1 alongside the module defines no command at all - it was never dot-sourced'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a folder with neither a .psd1 nor a .psm1 throws,
# rather than silently doing nothing
$emptyFolder = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $emptyFolder -Force | Out-Null
try {
    Import-LocalModule -Path $emptyFolder
    Assert-That -Condition $false -Message 'An empty folder throws (did not throw)'
}
catch {
    Assert-That -Condition ($_.Exception.Message -like "*$emptyFolder*") -Message 'An empty folder throws, naming the path'
}

# Cleanup
Remove-Module -Name 'ModuleWithManifest', 'BareModuleHelpers' -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $manifestModuleFolder, $bareModuleFolder, $emptyFolder -Recurse -Force

exit (Complete-TestRun)
