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

# Act - an open line, finished with an outcome
$closed = @(Get-HostMessage { Write-Doing 'building'; & $module { Complete-OpenLine -Outcome Failure } })
$open = & $module { $script:LineOpen }

# Assert
Assert-Equal -Expected @('  ▶ building ...', ' failed') -Actual @($closed.Message) `
    -Message 'The outcome''s default wording follows the open line'
Assert-Equal -Expected @('Cyan', 'Red') -Actual @($closed.Color) -Message 'in the outcome''s color'
Assert-Equal -Expected $false -Actual $open -Message 'and the line is no longer open'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - no line open
$own = @(Get-HostMessage { & $module { Complete-OpenLine -Outcome Skip -Text 'cached' } })

# Assert
Assert-Equal -Expected @('  ⏭️  cached') -Actual @($own.Message) `
    -Message 'With no line open, the outcome is a marker line of its own'
Assert-Equal -Expected @('DarkGray') -Actual @($own.Color) -Message 'in the same color'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - blank text, and text with a line break
$blank = @(Get-HostMessage { Write-Doing 'a'; & $module { Complete-OpenLine -Outcome Stopped -Text '  ' } })
$multi = @(Get-HostMessage { Write-Doing 'b'; & $module { Complete-OpenLine -Outcome Success -Text "ok`nsee the log" } })

# Assert
Assert-Equal -Expected @('  ▶ a ...', ' stopped') -Actual @($blank.Message) -Message 'Blank text keeps the default wording'
Assert-Equal -Expected @('  ▶ b ...', ' ok', '    see the log') -Actual @($multi.Message) `
    -Message 'A later line of the outcome sits under the open line''s text'

exit (Complete-TestRun)
