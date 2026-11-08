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
$null = @(Get-HostMessage { Write-Step 'Build' })

# Act
$state = & $module { Get-StepState }

# Assert
Assert-Equal -Expected 1 -Actual $state.Number -Message 'The current step''s number is returned'
Assert-Equal -Expected 'Step 1: Build' -Actual $state.Label -Message 'and its label'

exit (Complete-TestRun)
