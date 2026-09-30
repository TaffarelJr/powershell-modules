#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

# A 20-column console leaves a header 18 columns: the console's width less 2.
$rule = '─' * 18

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - blank line, rule, left-justified text, rule, blank line
$lines = @(Get-HostOutput { Write-Header 'Build' })

# Assert
Assert-Equal -Expected @('', $rule, 'Build'.PadRight(18), $rule, '') -Actual $lines `
    -Message 'Write-Header renders a blank line, a rule, the text padded to the rule, a rule, and a blank line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - every line of the box is cyan; the blank lines around it are the host's own
$messages = @(Get-HostMessage { Write-Header 'Build' })

# Assert
Assert-Equal -Expected @('Cyan', 'Cyan', 'Cyan') -Actual @($messages[1..3].Color) `
    -Message 'The rules and the text are cyan'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - embedded newlines grow the header vertically
$multiline = @(Get-HostOutput { Write-Header "first line`nsecond line" })

# Assert
Assert-Equal -Expected @('', $rule, 'first line'.PadRight(18), 'second line'.PadRight(18), $rule, '') `
    -Actual $multiline `
    -Message 'Each embedded line renders on its own row'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - -Trim narrows the rule to fit the text
$trimmed = @(Get-HostOutput { Write-Header 'hi' -Trim })

# Assert
Assert-Equal -Expected @('', '──', 'hi', '──', '') -Actual $trimmed `
    -Message '-Trim shrinks the rule to the longest line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - text too long for the console wraps instead of running past it
$wrapped = @(Get-HostOutput { Write-Header 'aaaa bbbb cccc dddd eeee' })

# Assert
Assert-Equal -Expected @('', $rule, 'aaaa bbbb cccc'.PadRight(18), 'dddd eeee'.PadRight(18), $rule, '') `
    -Actual $wrapped `
    -Message 'A line too long for the console wraps at a word boundary'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - the ambient indent moves the header in and narrows it
$indented = @(Invoke-Indented -Width 4 { Get-HostOutput { Write-Header 'Build' } })

# Assert
Assert-Equal -Expected @('', ('    ' + ('─' * 14)), ('    ' + 'Build'.PadRight(14)), ('    ' + ('─' * 14)), '') `
    -Actual $indented `
    -Message 'The indent is spent from the width, so the header still fits the console'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 80
$margin = ' ' * 100

# Act - an ambient indent wider than the console
$beyond = @(Invoke-Indented -Width 100 { Get-HostOutput { Write-Header 'hello' } })

# Assert
Assert-Equal -Expected @('', "$margin─────", "${margin}hello", "$margin─────", '') -Actual $beyond `
    -Message 'An indent wider than the console still gets rules as wide as the text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - pipeline input, and empty text
$piped = @(Get-HostOutput { 'a', 'b' | Write-Header })
$empty = @(Get-HostOutput { Write-Header '' })

# Assert
Assert-Equal -Expected 10 -Actual $piped.Count -Message 'Piping two strings renders two separate headers'
Assert-Equal -Expected @('', $rule, '(no message)'.PadRight(18), $rule, '') -Actual $empty `
    -Message 'Empty text renders the placeholder, as every other writer does'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - blank and $null text with -Trim
$blank = @(Get-HostOutput { Write-Header '  ' -Trim })
$nothing = @(Get-HostOutput { Write-Header $null -Trim })

# Assert
Assert-Equal -Expected @('', ('─' * 12), '(no message)', ('─' * 12), '') -Actual $blank `
    -Message 'A blank header is never just blank lines'
Assert-Equal -Expected @('', ('─' * 12), '(no message)', ('─' * 12), '') -Actual $nothing `
    -Message 'and neither is a $null one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 30
$colored = "`e[31mRED`e[0m text"

# Act - color codes take no room on screen
$trimmed = @(Get-HostOutput { Write-Header $colored -Trim })

# Assert
Assert-Equal -Expected @('', ('─' * 8), $colored, ('─' * 8), '') -Actual $trimmed `
    -Message '-Trim fits the rule to the text as it shows, not counting its color codes'

exit (Complete-TestRun)
