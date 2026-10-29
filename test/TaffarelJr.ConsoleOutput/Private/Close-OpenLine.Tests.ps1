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
$null = @(Get-HostOutput { Write-Doing 'building' })

# Act
$closing = @(Get-HostMessage { & $module { Close-OpenLine } })
$stillOpen = & $module { $script:LineOpen }

# Assert
Assert-Equal -Expected 1 -Actual $closing.Count -Message 'An open line is ended with one write'
Assert-Equal -Expected '' -Actual $closing[0].Message -Message 'that is empty, so only the line ends'
Assert-That -Condition (-not $closing[0].NoNewLine) -Message 'and it ends the line'
Assert-That -Condition (-not $stillOpen) -Message 'Nothing is open afterwards'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - nothing open
$nothing = @(Get-HostOutput { & $module { Close-OpenLine } })

# Assert
Assert-Equal -Expected 0 -Actual $nothing.Count -Message 'With no line open, nothing is written'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
$null = @(Get-HostOutput { Write-Doing 'building' })

# Act - a second call has nothing left to close
$null = @(Get-HostOutput { & $module { Close-OpenLine } })
$again = @(Get-HostOutput { & $module { Close-OpenLine } })

# Assert
Assert-Equal -Expected 0 -Actual $again.Count -Message 'A line is only closed once'

exit (Complete-TestRun)
