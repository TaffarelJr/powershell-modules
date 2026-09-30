#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

# Arrange
$before = Get-Indent

# Act
Push-Indent -Width 4

# Assert
Assert-Equal -Expected ($before + 4) -Actual (Get-Indent) -Message 'Push-Indent adds its width to the ambient indent'
Pop-Indent

# Arrange / Act - default width
Push-Indent

# Assert
Assert-Equal -Expected 2 -Actual (Get-Indent) -Message 'Push-Indent defaults to a width of 2'
Pop-Indent

# Arrange / Act - two different widths stack
Push-Indent -Width 3
Push-Indent -Width 5

# Assert
Assert-Equal -Expected 8 -Actual (Get-Indent) -Message 'Two pushes with different widths sum together'
Pop-Indent
Pop-Indent

exit (Complete-TestRun)
