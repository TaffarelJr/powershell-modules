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
Push-Indent -Width 4

# Assert
Assert-Equal -Expected 4 -Actual (Get-Indent) -Message 'Push-Indent adds its width to the ambient indent'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - default width
Push-Indent

# Assert
Assert-Equal -Expected 2 -Actual (Get-Indent) -Message 'Push-Indent defaults to a width of 2'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - two different widths stack
Push-Indent -Width 3
Push-Indent -Width 5

# Assert
Assert-Equal -Expected 8 -Actual (Get-Indent) -Message 'Two pushes with different widths sum together'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a width of zero is a level that adds nothing
Push-Indent -Width 0
$depth = & $module { $script:IndentStack.Count }
$indent = Get-Indent
$warnings = @(Get-WarningOutput { Pop-Indent })

# Assert
Assert-Equal -Expected 1 -Actual $depth -Message 'A zero-width level is still a level on the stack'
Assert-Equal -Expected 0 -Actual $indent -Message 'that adds nothing to the indent'
Assert-Equal -Expected 0 -Actual $warnings.Count -Message 'and pops cleanly, with nothing to warn about'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act / Assert - a negative width
Assert-Throws -ScriptBlock { Push-Indent -Width -2 } -MessageLike '*Width*' `
    -Message 'A negative width is refused, since it would make every later line fail'
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'and nothing is pushed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a caller forces a new value into the exported default
Reset-ConsoleOutputState -Module $module
Set-Variable -Name DefaultIndentWidth -Value 7 -Scope Global -Force

# Act
Push-Indent
$pushed = Get-Indent
$lineIndent = & $module { Format-LineIndent }

# Assert
Assert-Equal -Expected 2 -Actual $pushed `
    -Message 'The default width is the module''s own, whatever a caller does to the exported one'
Assert-Equal -Expected '    ' -Actual $lineIndent -Message 'and so is the base indent every line gets'

exit (Complete-TestRun)
