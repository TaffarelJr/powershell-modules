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
$line = @(Get-HostMessage { & $module { Open-DoingLine -Text 'building' } })
$state = & $module { [PSCustomObject]@{ Open = $script:LineOpen; Continuation = $script:OpenLineContinuation } }

# Assert
Assert-Equal -Expected @('  ▶ building ...') -Actual @($line.Message) -Message 'The text is written behind the marker'
Assert-Equal -Expected @($true) -Actual @($line.NoNewLine) -Message 'and the line is left open'
Assert-Equal -Expected $true -Actual $state.Open -Message 'The line is recorded as open'
Assert-Equal -Expected '    ' -Actual $state.Continuation -Message 'with where a later line of its outcome goes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - a line already open
$second = @(Get-HostMessage { & $module { Open-DoingLine -Text 'a'; Open-DoingLine -Text 'b' } })

# Assert
Assert-Equal -Expected @('  ▶ a ...', '', '  ▶ b ...') -Actual @($second.Message) `
    -Message 'An open line is ended before the next one starts'

exit (Complete-TestRun)
