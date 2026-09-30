#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1'
$module = Import-Module $modulePath -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$versioned = [PSCustomObject]@{ Name = 'Pester'; MinimumVersion = [Version]'5.0.0' }
$unversioned = [PSCustomObject]@{ Name = 'Pester'; MinimumVersion = $null }

# Act
$withVersion = & $module { Get-ModuleRequirementText @args } -Module $versioned
$withoutVersion = & $module { Get-ModuleRequirementText @args } -Module $unversioned
$piped = $versioned | & $module { process { Get-ModuleRequirementText -Module $_ } }

# Assert
Assert-Equal -Expected 'Pester 5.0.0 or later' -Actual $withVersion `
    -Message 'A module with a minimum version is named with it'
Assert-Equal -Expected 'Pester' -Actual $withoutVersion -Message 'and one without is named alone'
Assert-Equal -Expected 'Pester 5.0.0 or later' -Actual $piped -Message 'The module can be piped in'

exit (Complete-TestRun)
