#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - modules "installed" on PSModulePath, one with two versions
$sandbox = New-RequiredModulesSandbox
New-FakeModule -Root $sandbox -Name 'Probe.Single' -Version '1.0.0'
New-FakeModule -Root $sandbox -Name 'Probe.Double' -Version '1.0.0'
New-FakeModule -Root $sandbox -Name 'Probe.Double' -Version '2.5.0'

# Act
$none = @(& $module { Get-InstalledModuleVersion -Name 'Probe.NotThere' })
$single = & $module { Get-InstalledModuleVersion -Name 'Probe.Single' }
$double = & $module { Get-InstalledModuleVersion -Name 'Probe.Double' }

# Assert
Assert-Equal -Expected 0 -Actual $none.Count -Message 'A module that is not installed gives nothing at all, not a $null'
Assert-Equal -Expected ([Version]'1.0.0') -Actual $single -Message 'The one installed version is returned'
Assert-Equal -Expected ([Version]'2.5.0') -Actual $double `
    -Message 'With several versions installed, the highest is returned'

#───────────────────────────────────────────────────────────────────────────────
# Act - names with wildcard characters, which match nothing literally
$star = @(& $module { Get-InstalledModuleVersion -Name 'Probe.*' })
$question = @(& $module { Get-InstalledModuleVersion -Name 'Probe.Singl?' })

# Assert
Assert-Equal -Expected 0 -Actual $star.Count -Message 'A * in the name is a character, not a wildcard'
Assert-Equal -Expected 0 -Actual $question.Count -Message 'A ? in the name is a character, not a wildcard'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module imported by its path from a folder that is NOT on PSModulePath
$outside = "$sandbox-outside"
New-FakeModule -Root $outside -Name 'Probe.Loose' -Version '3.0.0'
$looseManifest = Join-Path $outside 'Probe.Loose' '3.0.0' 'Probe.Loose.psd1'
$null = Import-Module $looseManifest -Global -Force

# Act
$listed = @(Get-Module -Name 'Probe.Loose' -ListAvailable)
$loose = & $module { Get-InstalledModuleVersion -Name 'Probe.Loose' }

# Assert
Assert-Equal -Expected 0 -Actual $listed.Count -Message 'Precondition: PSModulePath does not list the module'
Assert-Equal -Expected ([Version]'3.0.0') -Actual $loose `
    -Message 'A loaded module counts even though PSModulePath does not list it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a loaded version higher than the installed one, and the reverse
New-FakeModule -Root $outside -Name 'Probe.Single' -Version '9.0.0'
$null = Import-Module (Join-Path $outside 'Probe.Single' '9.0.0' 'Probe.Single.psd1') -Global -Force
New-FakeModule -Root $sandbox -Name 'Probe.Double' -Version '7.0.0'
$null = Import-Module (Join-Path $sandbox 'Probe.Double' '1.0.0' 'Probe.Double.psd1') -Global -Force

# Act
$loadedHigher = & $module { Get-InstalledModuleVersion -Name 'Probe.Single' }
$installedHigher = & $module { Get-InstalledModuleVersion -Name 'Probe.Double' }

# Assert
Assert-Equal -Expected ([Version]'9.0.0') -Actual $loadedHigher `
    -Message 'A loaded version higher than the installed one wins'
Assert-Equal -Expected ([Version]'7.0.0') -Actual $installedHigher `
    -Message 'An installed version higher than the loaded one wins'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - version 1.0.0 loaded by its path, and a higher 2.0.0 installed on PSModulePath
New-FakeModule -Root $outside -Name 'Probe.Pair' -Version '1.0.0'
$null = Import-Module (Join-Path $outside 'Probe.Pair' '1.0.0' 'Probe.Pair.psd1') -Global -Force
New-FakeModule -Root $sandbox -Name 'Probe.Pair' -Version '2.0.0'
New-FakeModule -Root $sandbox -Name 'Probe.Cold' -Version '1.0.0'

# Act
$highest = & $module { Get-InstalledModuleVersion -Name 'Probe.Pair' }
$enough = & $module { Get-InstalledModuleVersion -Name 'Probe.Pair' -MinimumVersion ([Version]'1.0.0') }
$notEnough = & $module { Get-InstalledModuleVersion -Name 'Probe.Pair' -MinimumVersion ([Version]'2.0.0') }

# Assert
Assert-Equal -Expected ([Version]'2.0.0') -Actual $highest `
    -Message 'With no minimum, the highest version there is is returned'
Assert-Equal -Expected ([Version]'1.0.0') -Actual $enough `
    -Message 'A loaded version that meets the minimum is returned as it is, without looking for a higher one'
Assert-Equal -Expected ([Version]'2.0.0') -Actual $notEnough `
    -Message 'A loaded version below the minimum is not enough, so the modules on disk are looked at too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a count of the scans of PSModulePath, which take seconds on a machine with many modules
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
$null = & $module { Get-InstalledModuleVersion -Name 'Probe.Pair' -MinimumVersion ([Version]'1.0.0') }
$afterLoaded = & $module { $script:ListScans }
$null = & $module { Get-InstalledModuleVersion -Name 'Probe.Pair' -MinimumVersion ([Version]'2.0.0') }
$afterBelow = & $module { $script:ListScans }
$null = & $module { Get-InstalledModuleVersion -Name 'Probe.Cold' -MinimumVersion ([Version]'1.0.0') }
$afterNotLoaded = & $module { $script:ListScans }

# Assert
Assert-Equal -Expected 0 -Actual $afterLoaded `
    -Message 'A loaded module that meets the minimum is found without scanning PSModulePath'
Assert-Equal -Expected 1 -Actual $afterBelow -Message 'one below it is looked for there'
Assert-Equal -Expected 2 -Actual $afterNotLoaded -Message 'and so is one that is not loaded'

# Cleanup
Remove-Module -Name 'Probe.*' -Force
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
