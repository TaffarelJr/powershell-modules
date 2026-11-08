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
$warnings = @(Get-WarningOutput { & $module { Write-WarningLine -Message 'one', 'two' } })

# Assert
Assert-Equal -Expected @('one', 'two') -Actual $warnings -Message 'Each message is written as a warning, in order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - an open "Doing" line
$interrupted = @(Get-HostMessage { Write-Doing 'x'; & $module { Write-WarningLine -Message 'w' } 3>$null })

# Assert
Assert-Equal -Expected @('  ▶ x ...', '') -Actual @($interrupted.Message) `
    -Message 'An open line is ended before the warning'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
$WarningPreference = 'Stop'

# Act / Assert - warnings that become errors
Assert-Throws -ScriptBlock { & $module { Write-WarningLine -Message 'w' } } -MessageLike '*w*' `
    -Message 'A warning the caller turned into an error is raised'
$after = @(& $module { Write-WarningLine -Message 'one', 'two' -AfterFailure } 3>&1)
$WarningPreference = 'Continue'

# Assert
Assert-Equal -Expected 2 -Actual $after.Count -Message 'but after a failure every warning is written and none is raised'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - nothing to write
$none = @(Get-HostMessage { Write-Doing 'x'; & $module { Write-WarningLine -Message @() } })

# Assert
Assert-Equal -Expected @('  ▶ x ...') -Actual @($none.Message) -Message 'With no message, an open line stays open'

exit (Complete-TestRun)
