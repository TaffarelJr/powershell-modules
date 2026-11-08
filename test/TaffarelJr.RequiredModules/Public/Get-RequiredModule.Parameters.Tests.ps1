#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$sandbox = New-RequiredModulesSandbox
$command = Get-Command Get-RequiredModule
$manifest = New-ManifestFile -Directory $sandbox -Name 'pspath.psd1' `
    -Content "@{ 'Probe.Piped' = @{ MinimumVersion = '1.0.0' } }"
$psPathOnly = [PSCustomObject]@{ PSPath = "Microsoft.PowerShell.Core\FileSystem::$manifest" }

# Act
$byPsPath = @($psPathOnly | Get-RequiredModule)
$byItem = @(Get-Item -LiteralPath $manifest | Get-RequiredModule)
$byHashtable = @(@{ 'Probe.Inline' = @{ MinimumVersion = '2.0.0' } } | Get-RequiredModule)
$byPath = @(Get-RequiredModule -Path $manifest)

# Assert
Assert-Equal -Expected 'ByData' -Actual $command.DefaultParameterSet `
    -Message 'The default parameter set is the manifest as data, the one a piped hashtable binds'
Assert-Equal -Expected @('ByData', 'ByPath') -Actual @($command.ParameterSets.Name | Sort-Object) `
    -Message 'and the other set is the path of a file'
Assert-Equal -Expected 'Probe.Piped' -Actual $byPsPath.Name `
    -Message 'An object with only a PSPath is read as a manifest path'
Assert-Equal -Expected 'Probe.Piped' -Actual $byItem.Name `
    -Message 'and so is the item Get-Item returns, which carries a PSPath and a FullName'
Assert-Equal -Expected 'Probe.Inline' -Actual $byHashtable.Name `
    -Message 'A piped hashtable is still read as the manifest itself, whichever set is the default'
Assert-Equal -Expected 'Probe.Piped' -Actual $byPath.Name `
    -Message 'and a path still binds the path set'

# Cleanup
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
