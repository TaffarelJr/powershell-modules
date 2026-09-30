#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module installed in two versions, and nothing loaded yet
$sandbox = New-RequiredModulesSandbox
New-FakeModule -Root $sandbox -Name 'Probe.Versioned' -Version '1.0.0'
New-FakeModule -Root $sandbox -Name 'Probe.Versioned' -Version '2.0.0'
$wantOne = [PSCustomObject]@{ Name = 'Probe.Versioned'; MinimumVersion = [Version]'1.0.0' }
$wantTwo = [PSCustomObject]@{ Name = 'Probe.Versioned'; MinimumVersion = [Version]'2.0.0' }

# Act
Import-RequiredModule -Module $wantOne
$first = Get-FakeModuleState
$loaded = @(Get-Module -Name 'Probe.Versioned')

# Assert
Assert-Equal -Expected 1 -Actual $loaded.Count -Message 'The module is loaded after Import-RequiredModule'
Assert-That -Condition ($first -like 'Probe.Versioned 2.0.0 *') `
    -Message 'The newest version that meets the minimum is the one imported'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same requirement again, with the module already loaded
Import-RequiredModule -Module $wantOne
$second = Get-FakeModuleState
Import-RequiredModule -Module $wantTwo
$third = Get-FakeModuleState

# Assert
Assert-Equal -Expected $first -Actual $second `
    -Message 'A module already loaded at a good enough version is not reloaded, so its state survives'
Assert-Equal -Expected $first -Actual $third -Message 'The same holds when the minimum is exactly the loaded version'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - only an older version loaded, a newer one installed
Remove-Module -Name 'Probe.Versioned' -Force
$null = Import-Module (Join-Path $sandbox 'Probe.Versioned' '1.0.0' 'Probe.Versioned.psd1') -Global -Force

# Act
Import-RequiredModule -Module $wantTwo
$upgraded = Get-FakeModuleState

# Assert
Assert-That -Condition ($upgraded -like 'Probe.Versioned 2.0.0 *') `
    -Message 'When only an older version is loaded, the newer one is loaded and answers'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module imported by its path from a folder NOT on PSModulePath,
# which Test-RequiredModule counts as satisfied
Remove-Module -Name 'Probe.*' -Force
$outside = "$sandbox-outside"
New-FakeModule -Root $outside -Name 'Probe.Loose' -Version '3.0.0'
$null = Import-Module (Join-Path $outside 'Probe.Loose' '3.0.0' 'Probe.Loose.psd1') -Global -Force
$loose = [PSCustomObject]@{ Name = 'Probe.Loose'; MinimumVersion = [Version]'2.0.0' }
$looseBefore = Get-FakeModuleState
$satisfied = Test-RequiredModule -Module $loose

# Act
Import-RequiredModule -Module $loose
$looseAfter = Get-FakeModuleState

# Assert
Assert-Equal -Expected $true -Actual $satisfied -Message 'Precondition: Test-RequiredModule counts the loaded module'
Assert-Equal -Expected $looseBefore -Actual $looseAfter `
    -Message 'A module loaded by its path, which Test-RequiredModule counts, imports without an error and is left as it is'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same loaded module, with a minimum that is exactly its version
$exact = [PSCustomObject]@{ Name = 'Probe.Loose'; MinimumVersion = [Version]'3.0.0' }

# Act
Import-RequiredModule -Module $exact
$exactAfter = Get-FakeModuleState

# Assert
Assert-Equal -Expected $looseBefore -Actual $exactAfter `
    -Message 'A module loaded at exactly the minimum version is good enough, and is left as it is'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the same loaded module below the minimum still has to
# be found on PSModulePath
Assert-Throws -ScriptBlock {
    Import-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.Loose'; MinimumVersion = [Version]'4.0.0' })
} -MessageLike '*Probe.Loose*' -Message 'A loaded module below the minimum is not taken as good enough'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - modules with a name and no minimum version: one not loaded, one loaded
Remove-Module -Name 'Probe.*' -Force
$anyVersion = [PSCustomObject]@{ Name = 'Probe.Versioned' }

# Act
Import-RequiredModule -Module $anyVersion
$anyFirst = Get-FakeModuleState
Import-RequiredModule -Module $anyVersion
$anySecond = Get-FakeModuleState

# Assert
Assert-That -Condition ($anyFirst -like 'Probe.Versioned 2.0.0 *') `
    -Message 'A name alone imports the newest version installed'
Assert-Equal -Expected $anyFirst -Actual $anySecond -Message 'and one already loaded, at any version, is left as it is'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - several modules, given as an array, through the pipeline, and by position
Remove-Module -Name 'Probe.*' -Force
New-FakeModule -Root $sandbox -Name 'Probe.Other' -Version '1.0.0'
$both = @(
    [PSCustomObject]@{ Name = 'Probe.Versioned'; MinimumVersion = [Version]'1.0.0' }
    [PSCustomObject]@{ Name = 'Probe.Other'; MinimumVersion = [Version]'1.0.0' }
)

# Act
Import-RequiredModule -Module $both
$fromArray = (Get-Module -Name 'Probe.*').Name | Sort-Object
Remove-Module -Name 'Probe.*' -Force
$both | Import-RequiredModule
$fromPipeline = (Get-Module -Name 'Probe.*').Name | Sort-Object
Remove-Module -Name 'Probe.*' -Force
Import-RequiredModule $both
$fromPosition = (Get-Module -Name 'Probe.*').Name | Sort-Object

# Assert
Assert-Equal -Expected 'Probe.Other, Probe.Versioned' -Actual ($fromArray -join ', ') `
    -Message 'An array given as -Module imports every module'
Assert-Equal -Expected 'Probe.Other, Probe.Versioned' -Actual ($fromPipeline -join ', ') `
    -Message 'Piped modules import every module'
Assert-Equal -Expected 'Probe.Other, Probe.Versioned' -Actual ($fromPosition -join ', ') `
    -Message 'Modules given by position import every module'

#───────────────────────────────────────────────────────────────────────────────
# Act - an empty list, as an empty manifest gives
$empty = @(Import-RequiredModule -Module @())

# Assert
Assert-Equal -Expected 0 -Actual $empty.Count -Message 'An empty list imports nothing and is not refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a module that cannot be found at the minimum version
Assert-Throws -ScriptBlock {
    Import-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.Other'; MinimumVersion = [Version]'99.0.0' })
} -MessageLike '*Probe.Other*' -Message 'A module that does not meet the minimum fails, naming the module'

# Cleanup

Remove-Module -Name 'Probe.*' -Force
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
