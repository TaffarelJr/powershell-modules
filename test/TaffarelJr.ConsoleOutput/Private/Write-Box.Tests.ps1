#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

# Write-Header and Write-Banner test the shapes; this covers what is the
# engine's own.

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - an open "Doing" line is closed before the box starts
$lines = @(Get-HostOutput { Write-Doing 'working'; & $module { Write-Box -Text 'hi' -Trim } })

# Assert
Assert-Equal -Expected @('  ▶ working ...', '', '', '──', 'hi', '──', '') -Actual $lines `
    -Message 'The open line ends first, then the box starts after its own blank line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - -Trim fits the longest line after wrapping, and is a no-op once that line fills the console
$wrapped = @(Get-HostOutput { & $module { Write-Box -Text 'aaaa bbbb cccc dddd eeee' -Trim } })
$full = @(Get-HostOutput { & $module { Write-Box -Text 'aaaaaaaaaaaaaaaaaa bbb' -Trim } })

# Assert
Assert-Equal -Expected @('', ('─' * 14), 'aaaa bbbb cccc', 'dddd eeee     ', ('─' * 14), '') -Actual $wrapped `
    -Message '-Trim fits the longest of the wrapped lines'
Assert-Equal -Expected @('', ('─' * 18), ('a' * 18), 'bbb'.PadRight(18), ('─' * 18), '') -Actual $full `
    -Message '-Trim does not narrow a box whose longest line already fills the console'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - a word longer than the box overflows rather than being cut
$overflow = @(Get-HostOutput { & $module { Write-Box -Text 'supercalifragilisticexpialidocious' -Bordered } })

# Assert
Assert-Equal -Expected '│ supercalifragilisticexpialidocious │' -Actual $overflow[2] `
    -Message 'An overlong word is kept whole, past the right border'
Assert-Equal -Expected @(('┌' + ('─' * 36) + '┐'), ('└' + ('─' * 36) + '┘')) -Actual @($overflow[1], $overflow[3]) `
    -Message 'and the rules widen to take it in'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20
$rule = '─' * 34

# Act - the same word in a header, with and without -Trim
$plain = @(Get-HostOutput { & $module { Write-Box -Text 'supercalifragilisticexpialidocious' } })
$trimmed = @(Get-HostOutput { & $module { Write-Box -Text 'supercalifragilisticexpialidocious' -Trim } })

# Assert
Assert-Equal -Expected @('', $rule, 'supercalifragilisticexpialidocious', $rule, '') -Actual $plain `
    -Message 'A header''s rules widen to take in an overlong word'
Assert-Equal -Expected $plain -Actual $trimmed -Message 'and -Trim changes nothing about it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 20

# Act - a tab is four spaces, so the box stays square
$tabbed = @(Get-HostOutput { & $module { Write-Box -Text "a`tb" -Bordered } })

# Assert
Assert-Equal -Expected 20 -Actual $tabbed[2].Length -Message 'A line with a tab is as wide as the rest of the box'
Assert-Equal -Expected ('│ ' + 'a    b'.PadRight(16) + ' │') -Actual $tabbed[2] -Message 'and the tab is four spaces'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Use-FakeHostWidth -Module $module -Width 3

# Act - a console narrower than the box's own borders still prints
$narrow = @(Get-HostOutput { & $module { Write-Box -Text 'hi' -Bordered } })

# Assert
Assert-Equal -Expected 5 -Actual $narrow.Count `
    -Message 'A console too narrow for a box still gets one, rather than an error'
Assert-Equal -Expected '│ hi │' -Actual $narrow[2] -Message 'with the text kept whole'

exit (Complete-TestRun)
