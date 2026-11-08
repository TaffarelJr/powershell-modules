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
$one = @(Get-HostMessage { & $module { Write-MarkerLine -Text 'hello' -Outcome Failure } })

# Assert
Assert-Equal -Expected @('  ❌ hello') -Actual @($one.Message) `
    -Message 'The line is the base indent, the outcome''s marker, then the text'
Assert-Equal -Expected 'Red' -Actual $one[0].Color -Message 'in the outcome''s color'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - an open "Doing" line is closed first
$interrupted = @(Get-HostMessage { Write-Doing 'working'; & $module { Write-MarkerLine -Text 'aside' -Outcome Info } })

# Assert
Assert-Equal -Expected @('  ▶ working ...', '', '  ℹ️  aside') -Actual @($interrupted.Message) `
    -Message 'The open line is ended before the marker line starts'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - the ambient indent, a blank message, and later lines
$indented = @(Invoke-Indented -Width 4 { Get-HostMessage { & $module { Write-MarkerLine -Text 'x' -Outcome Failure } } })
$blank = @(Get-HostMessage { & $module { Write-MarkerLine -Text ' ' -Outcome Failure } })
$multi = @(Get-HostMessage { & $module { Write-MarkerLine -Text "first`nsecond" -Outcome Detail } })

# Assert
Assert-Equal -Expected '      ❌ x' -Actual $indented[0].Message -Message 'The ambient indent is added to the base indent'
Assert-Equal -Expected '  ❌ (no message)' -Actual $blank[0].Message -Message 'A blank message becomes the placeholder'
Assert-Equal -Expected @('     first', '     second') -Actual @($multi.Message) `
    -Message 'A later line sits three spaces in from the indent, under the text'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { & $module { Write-MarkerLine -Text 'x' -Outcome 'Done' } } -MessageLike '*Outcome*' `
    -Message 'An outcome that does not exist is refused'

exit (Complete-TestRun)
