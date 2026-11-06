#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange - before any step
Reset-ConsoleOutputState -Module $module

# Act
$label = Get-CurrentStep

# Assert
Assert-Equal -Expected '' -Actual $label -Message 'Get-CurrentStep is empty before any Write-Step call'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
$null = @(Get-HostOutput { Write-Step 'Build' })

# Act
$label = Get-CurrentStep

# Assert
Assert-Equal -Expected 'Step 1: Build' -Actual $label `
    -Message 'Get-CurrentStep reflects the most recent Write-Step call'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
$null = @(Get-HostOutput { Write-Step 'Build'; Write-Step 'Test' })

# Act
$label = Get-CurrentStep

# Assert
Assert-Equal -Expected 'Step 2: Test' -Actual $label `
    -Message 'A second Write-Step replaces the label rather than nesting'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$declared = (Get-Command Get-CurrentStep).OutputType.ForEach('Type')

# Assert
Assert-Equal -Expected @([string]) -Actual @($declared) -Message 'Get-CurrentStep declares that it returns a string'

exit (Complete-TestRun)
