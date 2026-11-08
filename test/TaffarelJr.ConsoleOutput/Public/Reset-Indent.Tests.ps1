#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange - levels a failed script left behind
Reset-ConsoleOutputState -Module $module
Push-Indent
Push-Indent -Width 4

# Act
$printed = @(Get-HostOutput { Reset-Indent })
$after = Get-Indent

# Assert
Assert-Equal -Expected 0 -Actual $after -Message 'Every level is taken off at once'
Assert-Equal -Expected 0 -Actual $printed.Count -Message 'and nothing is written'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - nothing pushed
$warnings = @(Get-WarningOutput { Reset-Indent })

# Assert
Assert-Equal -Expected 0 -Actual (Get-Indent) -Message 'With nothing pushed, the indent stays zero'
Assert-Equal -Expected 0 -Actual $warnings.Count -Message 'and there is no warning, as there would be from Pop-Indent'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a line a failed step left open
$after = @(Get-HostMessage { Write-Doing 'a'; Reset-Indent; Write-Done -Skip 'nothing to do' })

# Assert
Assert-Equal -Expected @('  ▶ a ...', '', '  ⏭️  nothing to do') -Actual @($after.Message) `
    -Message 'An open line is ended, so the next outcome does not land on it'

exit (Complete-TestRun)
