#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

# A 20-column console fills the whole 20 columns: two corners, two spaces of
# padding, and 16 columns of text.
$top = '┌' + ('─' * 18) + '┐'
$bottom = '└' + ('─' * 18) + '┘'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - blank line, a full box, blank line
$lines = @(Get-HostOutput { Write-Banner 'BUILD FAILED' })

# Assert
Assert-Equal -Expected @('', $top, ('│ ' + 'BUILD FAILED'.PadRight(16) + ' │'), $bottom, '') -Actual $lines `
    -Message 'Write-Banner renders a blank line, a bordered box with the text padded to its width, and a blank line'
Assert-That -Condition ($lines[1].Length -eq 20 -and $lines[2].Length -eq 20) `
    -Message 'Every line of the box is as wide as the console'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - every line of the box is cyan; the blank lines around it are the host's own
$messages = @(Get-HostMessage { Write-Banner 'BUILD FAILED' })

# Assert
Assert-Equal -Expected @('Cyan', 'Cyan', 'Cyan') -Actual @($messages[1..3].Color) `
    -Message 'The borders and the text are cyan'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - embedded newlines grow the banner vertically
$multiline = @(Get-HostOutput { Write-Banner "first line`nsecond line" })

# Assert
Assert-Equal `
    -Expected @('', $top, ('│ ' + 'first line'.PadRight(16) + ' │'), ('│ ' + 'second line'.PadRight(16) + ' │'), $bottom, '') `
    -Actual $multiline `
    -Message 'Each embedded line renders on its own row'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - -Trim narrows the box to fit the text
$trimmed = @(Get-HostOutput { Write-Banner 'hi' -Trim })

# Assert
Assert-Equal -Expected @('', '┌────┐', '│ hi │', '└────┘', '') -Actual $trimmed `
    -Message '-Trim shrinks the box to the longest line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - text too long for the console wraps instead of running past it
$wrapped = @(Get-HostOutput { Write-Banner 'aaaa bbbb cccc dddd eeee' })

# Assert
Assert-Equal `
    -Expected @('', $top, ('│ ' + 'aaaa bbbb cccc'.PadRight(16) + ' │'), ('│ ' + 'dddd eeee'.PadRight(16) + ' │'), $bottom, '') `
    -Actual $wrapped `
    -Message 'A line too long for the console wraps at a word boundary'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - the ambient indent moves the box in and narrows it
$indented = @(Invoke-Indented -Width 4 { Get-HostOutput { Write-Banner 'ok' } })

# Assert
Assert-Equal `
    -Expected @('', ('    ┌' + ('─' * 14) + '┐'), ('    │ ' + 'ok'.PadRight(12) + ' │'), ('    └' + ('─' * 14) + '┘'), '') `
    -Actual $indented `
    -Message 'The indent is spent from the width, so the box still fits the console'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 80
$margin = ' ' * 100

# Act - an ambient indent wider than the console
$beyond = @(Invoke-Indented -Width 100 { Get-HostOutput { Write-Banner 'hello' } })

# Assert
Assert-Equal -Expected @('', "$margin┌───────┐", "$margin│ hello │", "$margin└───────┘", '') -Actual $beyond `
    -Message 'An indent wider than the console still gets a box as wide as its text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - pipeline input, and empty text
$piped = @(Get-HostOutput { 'a', 'b' | Write-Banner })
$empty = @(Get-HostOutput { Write-Banner '' })

# Assert
Assert-Equal -Expected 10 -Actual $piped.Count -Message 'Piping two strings renders two separate banners'
Assert-Equal -Expected @('', $top, ('│ ' + '(no message)'.PadRight(16) + ' │'), $bottom, '') -Actual $empty `
    -Message 'Empty text renders the placeholder, as every other writer does'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20
$colored = "`e[31mRED`e[0m"

# Act - color codes take no room on screen
$trimmed = @(Get-HostOutput { Write-Banner $colored -Trim })
$full = @(Get-HostOutput { Write-Banner $colored })

# Assert
Assert-Equal -Expected @('', '┌─────┐', "│ $colored │", '└─────┘', '') -Actual $trimmed `
    -Message '-Trim fits the box to the text as it shows, not counting its color codes'
Assert-Equal -Expected ('│ ' + $colored + (' ' * 13) + ' │') -Actual $full[2] `
    -Message 'and a short colored line is padded out to the border by what shows'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 30

# Act - a line of only spaces, longer than the box
$spaces = @(Get-HostOutput { Write-Banner ("a`n" + (' ' * 40)) })

# Assert
Assert-Equal -Expected @(
    ''
    ('┌' + ('─' * 28) + '┐')
    ('│ ' + 'a'.PadRight(26) + ' │')
    ('│ ' + (' ' * 26) + ' │')
    ('└' + ('─' * 28) + '┘')
    ''
) -Actual $spaces -Message 'A line of spaces is cut to the box, so the right border stays in line'

exit (Complete-TestRun)
