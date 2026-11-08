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
$removed = & $module { Remove-IndentLevel }

# Assert
Assert-Equal -Expected $true -Actual $removed -Message 'A level is taken off'
Assert-Equal -Expected 3 -Actual (Get-Indent) -Message 'and it is the most recent one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act
$none = & $module { Remove-IndentLevel }

# Assert
Assert-Equal -Expected $false -Actual $none -Message 'With nothing pushed, nothing is taken off and false comes back'

exit (Complete-TestRun)
