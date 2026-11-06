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
$none = & $module { Format-LineIndent }

# Assert
Assert-Equal -Expected '  ' -Actual $none -Message 'With nothing pushed, a line sits the default indent width in'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Push-Indent -Width 3

# Act
$ambient = & $module { Format-LineIndent }

# Assert
Assert-Equal -Expected '     ' -Actual $ambient -Message 'The ambient indent is added to the default width'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Push-Indent -Width 3

# Act - an explicit indent replaces the ambient one for this call only
$explicit = & $module { Format-LineIndent -Indent 4 }
$zero = & $module { Format-LineIndent -Indent 0 }
$afterwards = Get-Indent

# Assert
Assert-Equal -Expected '      ' -Actual $explicit -Message '-Indent 4 replaces the ambient indent'
Assert-Equal -Expected '  ' -Actual $zero -Message 'An indent of 0 is a real override, not "use the ambient one"'
Assert-Equal -Expected 3 -Actual $afterwards -Message 'and the pushed indent is left alone'

exit (Complete-TestRun)
