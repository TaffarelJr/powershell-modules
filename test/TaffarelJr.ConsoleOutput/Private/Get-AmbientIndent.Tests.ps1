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
$none = & $module { Get-AmbientIndent }

# Assert
Assert-Equal -Expected 0 -Actual $none -Message 'With nothing pushed, the indent is zero'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Push-Indent -Width 3

# Act
$sum = Invoke-Indented -Width 5 { & $module { Get-AmbientIndent } }

# Assert
Assert-Equal -Expected 8 -Actual $sum -Message 'Every width Push-Indent or Invoke-Indented pushed is added up'

exit (Complete-TestRun)
