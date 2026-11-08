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

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
function Invoke-QuietCaller {
    $WarningPreference = 'SilentlyContinue'
    Pop-Indent
}

# Act - a caller function silences warnings with its own preference
$quiet = @(Invoke-QuietCaller 3>&1)

# Assert
Assert-Equal -Expected 0 -Actual $quiet.Count -Message 'A caller''s own warning preference is honored'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - nothing to pop, the warning silenced, while a "Doing" line is open
$silenced = @(Get-HostMessage { Write-Doing 'x'; Pop-Indent -WarningAction SilentlyContinue; Write-Done })

# Assert
Assert-Equal -Expected @('  ▶ x ...', ' done') -Actual @($silenced.Message) `
    -Message 'A warning the caller silenced leaves the open line alone'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - nothing to pop while a "Doing" line is open
$interrupted = @(Get-HostMessage { Write-Doing 'x'; Pop-Indent 3>$null })

# Assert
Assert-Equal -Expected @('  ▶ x ...', '') -Actual @($interrupted.Message) `
    -Message 'The warning ends the open line first, so it does not run on to the end of it'

exit (Complete-TestRun)
