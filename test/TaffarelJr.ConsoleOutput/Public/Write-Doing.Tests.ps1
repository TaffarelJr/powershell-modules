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
$messages = @(Get-HostMessage { Write-Doing 'building' })

# Assert
Assert-Equal -Expected 1 -Actual $messages.Count -Message 'Write-Doing prints one piece of text'
Assert-Equal -Expected '  ▶ building ...' -Actual $messages[0].Message `
    -Message 'The line is the base indent, the marker, the text, and an ellipsis'
Assert-Equal -Expected 'Cyan' -Actual $messages[0].Color -Message 'The line is cyan'
Assert-That -Condition $messages[0].NoNewLine -Message 'The line is left open, for Write-Done to finish'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - anything printed in between closes the open line first,
# on its own line, instead of running on to the end of it
$interrupted = @(Get-HostMessage { Write-Doing 'building'; Write-Info 'aside' })

# Assert
Assert-Equal -Expected 3 -Actual $interrupted.Count `
    -Message 'An interrupting writer closes the open line, then prints its own'
Assert-Equal -Expected '' -Actual $interrupted[1].Message `
    -Message 'The closing line is empty - it just ends the open "Doing" line'
Assert-That -Condition (-not $interrupted[1].NoNewLine) -Message 'and it ends the line'
Assert-That -Condition ($interrupted[2].Message -like '*aside') `
    -Message 'The interrupting message prints after the closed line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - pipeline input: the second item closes the first item's open line
# before opening its own, same as any other writer
$piped = @(Get-HostMessage { 'first', 'second' | Write-Doing })

# Assert
Assert-Equal -Expected @('  ▶ first ...', '', '  ▶ second ...') -Actual @($piped.Message) `
    -Message 'The second piped item closes the first, then opens its own'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - empty text is allowed, like every other writer
$empty = @(Get-HostMessage { Write-Doing '' })

# Assert
Assert-Equal -Expected '  ▶ (no message) ...' -Actual $empty[0].Message `
    -Message 'Empty text renders the placeholder instead of throwing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act
$ambient = @(Invoke-Indented -Width 3 { Get-HostMessage { Write-Doing 'y' } })

# Assert
Assert-Equal -Expected '     ▶ y ...' -Actual $ambient[0].Message `
    -Message 'The ambient indent applies automatically, on top of the base indent'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - text with more than one line
$multi = @(Invoke-Indented -Width 2 { Get-HostMessage { Write-Doing "first`nsecond" } })

# Assert
Assert-Equal -Expected @('    ▶ first', '      second ...') -Actual @($multi.Message) `
    -Message 'A later line is indented under the first line''s text, and the last one carries the ellipsis'
Assert-Equal -Expected @($false, $true) -Actual @($multi.NoNewLine) -Message 'Only the last line is left open'
Assert-Equal -Expected @('Cyan', 'Cyan') -Actual @($multi.Color) -Message 'and every line is cyan'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - the caller ignores this command's host output
$ignored = @(Get-HostMessage { Write-Doing 'hidden' -InformationAction Ignore; Write-Done })

# Assert
Assert-Equal -Expected @('  ✅ done') -Actual @($ignored.Message) `
    -Message 'A line that was never shown is not left open, so the outcome gets a line of its own'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act - the caller turns this command's host output into an error
try {
    Write-Doing 'x' -InformationAction Stop 6>$null
}
catch {
    $null = $_
}
$open = & $module { $script:LineOpen }

# Assert
Assert-Equal -Expected $true -Actual $open -Message 'A line printed before the error is recorded as open'

exit (Complete-TestRun)
