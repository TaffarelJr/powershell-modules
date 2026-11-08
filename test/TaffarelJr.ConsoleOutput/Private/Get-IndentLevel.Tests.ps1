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
Push-Indent -Width 3
Push-Indent -Width 5

# Act
$levels = @(& $module { Get-IndentLevel })

# Assert
Assert-Equal -Expected @(5, 3) -Actual $levels -Message 'The widths come back most recent first'
Assert-Equal -Expected 8 -Actual (Get-Indent) -Message 'and the stack is left as it was'

exit (Complete-TestRun)
