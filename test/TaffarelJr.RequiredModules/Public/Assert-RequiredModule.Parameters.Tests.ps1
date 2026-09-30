#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The test sets and reads the caller-session state the code under test uses.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module installed, and a manifest file that asks for it
$sandbox = New-RequiredModulesSandbox
Use-FakeInstaller -Module $module
Use-AssertSeam -Module $module
New-FakeModule -Root $sandbox -Name 'Probe.Present' -Version '2.0.0'
$manifest = New-ManifestFile -Directory $sandbox -Name 'pspath.psd1' `
    -Content "@{ 'Probe.Present' = @{ MinimumVersion = '1.0.0' } }"
$missingManifest = New-ManifestFile -Directory $sandbox -Name 'pspath-missing.psd1' `
    -Content "@{ 'Probe.Absent' = @{ MinimumVersion = '1.0.0' } }"
$command = Get-Command Assert-RequiredModule
$psPathOnly = [PSCustomObject]@{ PSPath = "Microsoft.PowerShell.Core\FileSystem::$manifest" }
$psPathMissing = [PSCustomObject]@{ PSPath = "Microsoft.PowerShell.Core\FileSystem::$missingManifest" }

# Act
$byPsPath = Invoke-Capturing { $psPathOnly | Assert-RequiredModule }
$byItem = Invoke-Capturing { Get-Item -LiteralPath $manifest | Assert-RequiredModule }
$byHashtable = Invoke-Capturing { @{ 'Probe.Present' = @{ MinimumVersion = '1.0.0' } } | Assert-RequiredModule }
$preview = Get-WhatIfOutput { $psPathMissing | Assert-RequiredModule -WhatIf 6>$null }

# Assert
Assert-Equal -Expected 'ByData' -Actual $command.DefaultParameterSet `
    -Message 'The default parameter set is the manifest as data, the one a piped hashtable binds'
Assert-Equal -Expected @('ByData', 'ByPath') -Actual @($command.ParameterSets.Name | Sort-Object) `
    -Message 'and the other set is the path of a file'
Assert-Equal -Expected $null -Actual $byPsPath.Error -Message 'An object with only a PSPath is read as a manifest path'
Assert-Equal -Expected $null -Actual $byItem.Error `
    -Message 'and so is the item Get-Item returns, which carries a PSPath and a FullName'
Assert-Equal -Expected $null -Actual $byHashtable.Error `
    -Message 'A piped hashtable is still read as the manifest itself, whichever set is the default'
Assert-Equal `
    -Expected @('What if: Performing the operation "Install module" on target "Probe.Absent 1.0.0 or later".') `
    -Actual $preview.Messages `
    -Message 'and the modules it names are the ones that manifest asks for'

# Cleanup
Remove-Module -Name 'Probe.*' -Force
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
