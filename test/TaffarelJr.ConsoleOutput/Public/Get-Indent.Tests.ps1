#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

# Arrange / Act / Assert - nothing pushed
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'Get-Indent is 0 with nothing pushed'

# Arrange
Push-Indent -Width 6

# Act / Assert
Assert-Equal -Expected 6 -Actual (Get-Indent) -Message 'Get-Indent reflects a single pushed width'
Pop-Indent

# Arrange
Push-Indent -Width 2
Push-Indent -Width 2
Push-Indent -Width 2

# Act / Assert
Assert-Equal -Expected 6 -Actual (Get-Indent) -Message 'Get-Indent sums every level on the stack'
Pop-Indent
Pop-Indent
Pop-Indent

exit (Complete-TestRun)
