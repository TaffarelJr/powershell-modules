#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module installed at 2.0.0
$sandbox = New-RequiredModulesSandbox
New-FakeModule -Root $sandbox -Name 'Probe.Installed' -Version '2.0.0'

# Act
$below = Test-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.Installed'; MinimumVersion = [Version]'1.0.0' })
$exact = Test-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.Installed'; MinimumVersion = [Version]'2.0.0' })
$above = Test-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.Installed'; MinimumVersion = [Version]'2.0.1' })

# Assert
Assert-Equal -Expected $true -Actual $below -Message 'A module installed above the minimum version is satisfied'
Assert-Equal -Expected $true -Actual $exact -Message 'A module installed at exactly the minimum version is satisfied'
Assert-Equal -Expected $false -Actual $above -Message 'A minimum version just above what is installed is not satisfied'

#───────────────────────────────────────────────────────────────────────────────
# Act - a module that isn't installed at all
$missing = Test-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.NotThere'; MinimumVersion = [Version]'1.0.0' })

# Assert
Assert-Equal -Expected $false -Actual $missing -Message 'A module that is not installed at all is not satisfied'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module the machine has for certain, under its real name
$builtIn = [PSCustomObject]@{ Name = 'Microsoft.PowerShell.Management'; MinimumVersion = [Version]'3.0.0' }

# Act
$shipped = Test-RequiredModule -Module $builtIn

# Assert
Assert-Equal -Expected $true -Actual $shipped -Message 'A module that ships with PowerShell is satisfied'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module loaded by its path, with nothing on PSModulePath to list
$outside = "$sandbox-outside"
New-FakeModule -Root $outside -Name 'Probe.Loose' -Version '3.0.0'
$null = Import-Module (Join-Path $outside 'Probe.Loose' '3.0.0' 'Probe.Loose.psd1') -Global -Force

# Act
$loaded = Test-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.Loose'; MinimumVersion = [Version]'3.0.0' })
$loadedTooOld = Test-RequiredModule `
    -Module ([PSCustomObject]@{ Name = 'Probe.Loose'; MinimumVersion = [Version]'3.0.1' })

# Assert
Assert-Equal -Expected $true -Actual $loaded `
    -Message 'A module imported by its path is satisfied, as Import-RequiredModule would use it'
Assert-Equal -Expected $false -Actual $loadedTooOld -Message 'A loaded module still has to meet the minimum version'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a count of the scans of PSModulePath, which take seconds on a machine with many modules
$module = Get-Module TaffarelJr.RequiredModules
& $module {
    $script:ListScans = 0
    function script:Get-Module {
        if ($args -contains '-ListAvailable') {
            $script:ListScans++
        }

        Microsoft.PowerShell.Core\Get-Module @args
    }
}

# Act
$null = Test-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.Loose'; MinimumVersion = [Version]'1.0.0' })
$afterLoaded = & $module { $script:ListScans }
$null = Test-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.Installed'; MinimumVersion = [Version]'1.0.0' })
$afterInstalled = & $module { $script:ListScans }

# Assert
Assert-Equal -Expected 0 -Actual $afterLoaded `
    -Message 'A loaded module that meets the minimum is answered without scanning PSModulePath'
Assert-Equal -Expected 1 -Actual $afterInstalled -Message 'and one that is only installed takes a scan'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - names with wildcard characters, which must not match other modules
Assert-Throws `
    -ScriptBlock { Test-RequiredModule -Module ([PSCustomObject]@{ Name = '*'; MinimumVersion = [Version]'1.0.0' }) } `
    -MessageLike "*'*'*is not a valid module name*" `
    -Message 'A * as the name is refused, not taken to match every module'
Assert-Throws `
    -ScriptBlock {
        Test-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.Install*'; MinimumVersion = [Version]'1.0.0' })
    } `
    -MessageLike "*'Probe.Install*'*is not a valid module name*" `
    -Message 'and so is a name ending in *, which would match the module it is the start of'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two modules, one satisfied and one not
$satisfied = [PSCustomObject]@{ Name = 'Probe.Installed'; MinimumVersion = [Version]'1.0.0' }
$unsatisfied = [PSCustomObject]@{ Name = 'Probe.Installed'; MinimumVersion = [Version]'99.0.0' }

# Act
$piped = @(@($satisfied, $unsatisfied) | Test-RequiredModule)
$array = @(Test-RequiredModule -Module @($unsatisfied, $satisfied))

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count -Message 'Piping two modules through tests each one'
Assert-Equal -Expected $true -Actual $piped[0] -Message 'The first piped result is for the first module'
Assert-Equal -Expected $false -Actual $piped[1] -Message 'The second piped result is for the second module'
Assert-Equal -Expected 2 -Actual $array.Count -Message 'An array given as -Module is tested one module at a time'
Assert-Equal -Expected $false -Actual $array[0] -Message 'The first answer for an array is for the first module'
Assert-Equal -Expected $true -Actual $array[1] -Message 'The second answer for an array is for the second module'

#───────────────────────────────────────────────────────────────────────────────
# Act - a module with a name and no minimum version, installed and not
$anyInstalled = Test-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.Installed' })
$anyMissing = Test-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.NotThere'; MinimumVersion = $null })

# Assert
Assert-Equal -Expected $true -Actual $anyInstalled -Message 'A name alone is satisfied by any installed version'
Assert-Equal -Expected $false -Actual $anyMissing -Message 'but not by a module that is not installed'

#───────────────────────────────────────────────────────────────────────────────
# Act - a module given by position, and an empty list, as an empty manifest gives
$positional = Test-RequiredModule $satisfied
$empty = @(Test-RequiredModule -Module @())

# Assert
Assert-Equal -Expected $true -Actual $positional -Message 'The module can be given by position'
Assert-Equal -Expected 0 -Actual $empty.Count -Message 'An empty list is answered with nothing, not refused'

# Cleanup
Remove-Module -Name 'Probe.*' -Force
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
