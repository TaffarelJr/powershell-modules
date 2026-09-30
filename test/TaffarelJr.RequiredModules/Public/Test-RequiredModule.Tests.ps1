#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force

# Arrange - a module that's always present at any reasonable minimum version
$satisfied = [pscustomobject]@{ Name = 'Microsoft.PowerShell.Management'; MinimumVersion = [version]'3.0.0' }

# Act / Assert
Assert-That -Condition (Test-RequiredModule -Module $satisfied) -Message 'A module installed at or above the minimum version is satisfied'

# Arrange - an impossibly high version of the same module
$unsatisfied = [pscustomobject]@{ Name = 'Microsoft.PowerShell.Management'; MinimumVersion = [version]'999.0.0' }

# Act / Assert
Assert-That -Condition (-not (Test-RequiredModule -Module $unsatisfied)) -Message 'A minimum version higher than anything installed is not satisfied'

# Arrange - a module that isn't installed at all
$missing = [pscustomobject]@{ Name = 'ThisModuleDoesNotExistXyz'; MinimumVersion = [version]'1.0.0' }

# Act / Assert
Assert-That -Condition (-not (Test-RequiredModule -Module $missing)) -Message 'A module that is not installed at all is not satisfied'

# Arrange / Act - pipeline input
$results = @($satisfied, $unsatisfied) | Test-RequiredModule

# Assert
Assert-Equal -Expected 2 -Actual $results.Count -Message 'Piping two modules through tests each one'
Assert-Equal -Expected $true -Actual $results[0] -Message 'The first piped result is correct'
Assert-Equal -Expected $false -Actual $results[1] -Message 'The second piped result is correct'

exit (Complete-TestRun)
