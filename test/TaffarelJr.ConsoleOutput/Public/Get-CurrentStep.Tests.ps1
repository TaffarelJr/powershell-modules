#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - before any step
Assert-Equal -Expected '' -Actual (Get-CurrentStep) -Message 'Get-CurrentStep is empty before any Write-Step call'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$null = Get-HostOutput { Write-Step 'Build' }

# Act / Assert
Assert-Equal -Expected 'Step 1: Build' -Actual (Get-CurrentStep) -Message 'Get-CurrentStep reflects the most recent Write-Step call'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$null = Get-HostOutput { Write-Step 'Test' }

# Act / Assert
Assert-Equal -Expected 'Step 2: Test' -Actual (Get-CurrentStep) -Message 'A second Write-Step replaces the label rather than nesting'

#───────────────────────────────────────────────────────────────────────────────
# Act
Clear-Step

# Assert
Assert-Equal -Expected '' -Actual (Get-CurrentStep) -Message 'Clear-Step empties the current step label'

exit (Complete-TestRun)
