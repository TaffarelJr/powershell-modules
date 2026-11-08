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
$saved = @(& $module { Get-IndentLevel })
Push-Indent -Width 9

# Act
& $module { param($s) Restore-IndentLevel -Level $s } $saved
$after = @(& $module { Get-IndentLevel })

# Assert
Assert-Equal -Expected @(5, 3) -Actual $after -Message 'The stack is put back exactly, in the same order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Push-Indent -Width 4

# Act
& $module { Restore-IndentLevel }

# Assert
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'Given no levels, the stack is emptied'

exit (Complete-TestRun)
