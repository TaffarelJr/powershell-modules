#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

# Arrange
Push-Indent -Width 4

# Act
Pop-Indent

# Assert
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'Pop-Indent removes exactly the width its matching Push-Indent added'

# Arrange
Push-Indent -Width 3
Push-Indent -Width 5

# Act
Pop-Indent

# Assert
Assert-Equal -Expected 3 -Actual (Get-Indent) -Message 'Pop-Indent removes only the most recently pushed width'
Pop-Indent

# Act - popping with nothing pushed
$warnings = @(Pop-Indent 3>&1)

# Assert
Assert-That -Condition ($warnings.Count -gt 0) -Message 'Popping with nothing pushed warns instead of throwing'
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'Indent stays at 0 after an unmatched pop'

exit (Complete-TestRun)
