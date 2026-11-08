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
$messages = @(Get-HostMessage { Write-Failure 'built the project' })

# Assert
Assert-Equal -Expected 1 -Actual $messages.Count -Message 'Write-Failure prints exactly one line'
Assert-Equal -Expected '  ❌ built the project' -Actual $messages[0].Message `
    -Message 'The line is the base indent, the marker, then the text'
Assert-Equal -Expected 'Red' -Actual $messages[0].Color -Message 'The line is Red'
Assert-That -Condition (-not $messages[0].NoNewLine) -Message 'The line is ended, not left open'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - blank text
$blank = @(Get-HostMessage { Write-Failure '   ' })

# Assert
Assert-Equal -Expected '  ❌ (no message)' -Actual $blank[0].Message `
    -Message 'Blank text renders the placeholder instead of an empty line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - pipeline input
$piped = @(Get-HostMessage { 'first', 'second' | Write-Failure })

# Assert
Assert-Equal -Expected @('  ❌ first', '  ❌ second') -Actual @($piped.Message) `
    -Message 'Piping two strings prints two separate lines'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the ambient indent applies
$ambient = @(Invoke-Indented -Width 3 { Get-HostMessage { Write-Failure 'y' } })

# Assert
Assert-Equal -Expected '     ❌ y' -Actual $ambient[0].Message `
    -Message 'The ambient indent applies automatically, on top of the base indent'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a message with several lines, one of them blank
$multi = @(Get-HostMessage { Invoke-Indented -Width 2 { Write-Failure "first`nsecond`n`nfourth" } })

# Assert
Assert-Equal -Expected @('    ❌ first', '       second', '', '       fourth') -Actual @($multi.Message) `
    -Message 'Later lines line up under the first line''s text, and a blank line stays blank'
Assert-Equal -Expected @('Red') -Actual @($multi.Color | Select-Object -Unique) -Message 'Every line has the same color'

exit (Complete-TestRun)
