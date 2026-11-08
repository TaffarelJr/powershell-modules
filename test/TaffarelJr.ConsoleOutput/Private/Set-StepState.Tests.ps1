#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput
#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act
& $module { Set-StepState -Number 4 -Label 'Step 4: Pack' }

# Assert
Assert-Equal -Expected 'Step 4: Pack' -Actual (Get-CurrentStep) -Message 'The label is what Get-CurrentStep returns'

#───────────────────────────────────────────────────────────────────────────────
# Act
& $module { Set-StepState -Number 0 -Label '' }

# Assert
Assert-Equal -Expected '' -Actual (Get-CurrentStep) -Message 'An empty label forgets the step'

exit (Complete-TestRun)
