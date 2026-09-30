#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - text that already fits is returned as a single line
$result = @(& $module { Split-WrappedLine -Text 'short' -Width 20 })

# Assert
Assert-Equal -Expected @('short') -Actual $result -Message 'Text that fits within Width stays on one line, unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - embedded CR/LF always starts a new line,
# even when the combined text would otherwise fit
$result = @(& $module { Split-WrappedLine -Text "one`ntwo" -Width 20 })

# Assert
Assert-Equal -Expected @('one', 'two') -Actual $result `
    -Message 'An embedded newline always breaks the line, and each line is kept exactly'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a paragraph longer than Width wraps at word boundaries
$result = @(& $module { Split-WrappedLine -Text 'one two three four' -Width 7 })

# Assert
Assert-Equal -Expected @('one two', 'three', 'four') -Actual $result `
    -Message 'A paragraph longer than Width wraps at word boundaries, each line within Width, words in order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a single word longer than Width is left to overflow
# rather than split mid-word
$result = @(& $module { Split-WrappedLine -Text 'supercalifragilisticexpialidocious' -Width 10 })

# Assert
Assert-Equal -Expected @('supercalifragilisticexpialidocious') -Actual $result `
    -Message 'A single overlong word is returned whole, not split mid-word'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - empty text
$result = @(& $module { Split-WrappedLine -Text '' -Width 10 })

# Assert
Assert-Equal -Expected @('') -Actual $result -Message 'Empty text still returns one (empty) line, never zero'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - one line, and several lines piped straight on
$one = & $module { Split-WrappedLine -Text 'x' -Width 10 }
$piped = & $module { Split-WrappedLine -Text "a`nb`nc" -Width 10 } | Measure-Object

# Assert
Assert-Equal -Expected 'x' -Actual $one -Message 'A single line comes back as that line'
Assert-Equal -Expected 3 -Actual $piped.Count `
    -Message 'Each line is its own pipeline item, so the result pipes straight on'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a long line keeps its leading spaces on every line it wraps into
$indented = @(& $module { Split-WrappedLine -Text '    indented words that need wrapping' -Width 14 })

# Assert
Assert-Equal -Expected @('    indented', '    words that', '    need', '    wrapping') -Actual $indented `
    -Message 'A wrapped line stays indented, with the indent counted against the width'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a short indented line, and one whose indent is wider than the width
$short = @(& $module { Split-WrappedLine -Text '    short' -Width 40 })
$deep = @(& $module { Split-WrappedLine -Text '      a b c' -Width 3 })

# Assert
Assert-Equal -Expected @('    short') -Actual $short -Message 'A line that fits keeps its leading spaces untouched'
Assert-Equal -Expected @('      a', '      b', '      c') -Actual $deep `
    -Message 'An indent wider than the width still leaves room for one word per line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a line of only spaces, longer than the width
$spaces = @(& $module { Split-WrappedLine -Text (' ' * 40) -Width 30 })
$zeroWidth = @(& $module { Split-WrappedLine -Text '   ' -Width 0 })

# Assert
Assert-Equal -Expected @(' ' * 30) -Actual $spaces `
    -Message 'A line of only spaces is cut to the width, as it has no word to keep whole'
Assert-Equal -Expected @('') -Actual $zeroWidth -Message 'and to nothing at a width of zero'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a tab has no fixed width on screen, so it becomes four spaces
$tabbed = @(& $module { Split-WrappedLine -Text "a`tb" -Width 40 })

# Assert
Assert-Equal -Expected @('a    b') -Actual $tabbed -Message 'A tab is replaced by four spaces'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - CRLF is one break, and a blank line in the middle is kept
$crlf = @(& $module { Split-WrappedLine -Text "a`r`n`r`nb" -Width 40 })

# Assert
Assert-Equal -Expected @('a', '', 'b') -Actual $crlf `
    -Message 'CRLF breaks once, and an empty line between two is kept as an empty line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a lone CR, as progress output captured from a tool has
$cr = @(& $module { Split-WrappedLine -Text "abc`rXY" -Width 40 })

# Assert
Assert-Equal -Expected @('abc', 'XY') -Actual $cr `
    -Message 'A lone CR breaks the line too, rather than going out to overwrite it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - color codes take no room on screen
$colored = @(& $module { Split-WrappedLine -Text "`e[31maaaa`e[0m bbbb cc" -Width 9 })

# Assert
Assert-Equal -Expected @("`e[31maaaa`e[0m bbbb", 'cc') -Actual $colored `
    -Message 'A line is fitted by what shows, not counting its color codes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a width of zero still makes progress
$zero = @(& $module { Split-WrappedLine -Text 'a bb ccc' -Width 0 })

# Assert
Assert-Equal -Expected @('a', 'bb', 'ccc') -Actual $zero `
    -Message 'A width of zero puts one word on each line instead of looping or failing'

exit (Complete-TestRun)
