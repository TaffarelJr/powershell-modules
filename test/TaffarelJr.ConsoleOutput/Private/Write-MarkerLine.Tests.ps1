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
$one = @(Get-HostMessage { & $module { Write-MarkerLine -Text 'hello' -Marker '>> ' -Color Magenta } })

# Assert
Assert-Equal -Expected @('  >> hello') -Actual @($one.Message) `
    -Message 'The line is the base indent, the marker, then the text'
Assert-Equal -Expected 'Magenta' -Actual $one[0].Color -Message 'in the given color'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - an open "Doing" line is closed first
$interrupted = @(Get-HostMessage { Write-Doing 'working'; & $module { Write-MarkerLine -Text 'aside' -Marker '>> ' -Color Gray } })

# Assert
Assert-Equal -Expected @('  ▶ working ...', '', '  >> aside') -Actual @($interrupted.Message) `
    -Message 'The open line is ended before the marker line starts'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - indent, a blank message, and later lines
$indented = @(Get-HostMessage { & $module { Write-MarkerLine -Text 'x' -Marker '>> ' -Color Gray -Indent 4 } })
$blank = @(Get-HostMessage { & $module { Write-MarkerLine -Text ' ' -Marker '>> ' -Color Gray } })
$multi = @(Get-HostMessage { & $module { Write-MarkerLine -Text "first`nsecond" -Marker '>> ' -Color Gray } })

# Assert
Assert-Equal -Expected '      >> x' -Actual $indented[0].Message -Message '-Indent is added to the base indent'
Assert-Equal -Expected '  >> (no message)' -Actual $blank[0].Message -Message 'A blank message becomes the placeholder'
Assert-Equal -Expected @('  >> first', '     second') -Actual @($multi.Message) `
    -Message 'A later line sits three spaces in from the indent, under the text'

exit (Complete-TestRun)
