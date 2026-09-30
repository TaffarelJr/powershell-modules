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
Push-Indent -Width 4

Pop-Indent

# Assert
Assert-Equal -Expected 0 -Actual (Get-Indent) `
    -Message 'Pop-Indent removes exactly the width its matching Push-Indent added'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Push-Indent -Width 3
Push-Indent -Width 5

Pop-Indent

# Assert
Assert-Equal -Expected 3 -Actual (Get-Indent) -Message 'Pop-Indent removes only the most recently pushed width'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - popping with nothing pushed
$warnings = @(Get-WarningOutput { Pop-Indent })

# Assert
Assert-Equal -Expected @('Pop-Indent called with no matching Push-Indent.') -Actual $warnings `
    -Message 'Popping with nothing pushed warns, naming the mismatch, instead of throwing'
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'Indent stays at 0 after an unmatched pop'

exit (Complete-TestRun)
