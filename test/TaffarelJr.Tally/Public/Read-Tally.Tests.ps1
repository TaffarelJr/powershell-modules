#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the default separator, one entry
$one = @(Read-Tally -Text '3 passed')

# Assert
Assert-Equal -Expected 1 -Actual $one.Count -Message 'A single entry parses to one result'
Assert-Equal -Expected 'passed' -Actual $one[0].Name -Message 'The name is read from the entry'
Assert-Equal -Expected 3 -Actual $one[0].Count -Message 'The count is read from the entry'
Assert-Equal -Expected 'System.Int64' -Actual $one[0].Count.GetType().FullName -Message 'as a [long]'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the default separator, several entries
$several = @(Read-Tally -Text '3 passed - 1 failed - 0 crashed')

# Assert
Assert-Equal -Expected 3 -Actual $several.Count -Message 'Every entry is parsed'
Assert-Equal -Expected @('passed', 'failed', 'crashed') -Actual $several.Name `
    -Message 'Names come back in the order they appear'

# .ForEach('Count'), not bare .Count - the array's own Count property
# shadows member-enumeration of each entry's Count property otherwise.
Assert-Equal -Expected @(3, 1, 0) -Actual $several.ForEach('Count') -Message 'Counts come back in the order they appear'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Separator must match whatever produced the text
$commaSeparated = @(Read-Tally -Text '3 passed, 1 failed' -Separator ', ')

# Assert
Assert-Equal -Expected @('passed', 'failed') -Actual $commaSeparated.Name `
    -Message '-Separator parses a non-default join correctly'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a part that isn't "<count> <name>" is skipped, not thrown
$withJunk = @(Read-Tally -Text '3 passed - not a tally - 1 failed')

# Assert
Assert-Equal -Expected @('passed', 'failed') -Actual $withJunk.Name `
    -Message 'A malformed part is skipped rather than breaking the whole parse'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$empty = @(Read-Tally -Text '')
$junkOnly = @(Read-Tally -Text 'nothing to see here')

# Assert
Assert-Equal -Expected 0 -Actual $empty.Count -Message 'For empty text nothing is written, and it is not an error'
Assert-Equal -Expected 0 -Actual $junkOnly.Count -Message 'and for text with no tally in it neither'

#───────────────────────────────────────────────────────────────────────────────
# Act
$lines = @('1 a', '2 b - 3 c' | Read-Tally)

# Assert
Assert-Equal -Expected @('a', 'b', 'c') -Actual $lines.Name `
    -Message 'Lines piped in are each read, every entry written in the order it appears'
Assert-Equal -Expected @(1, 2, 3) -Actual $lines.ForEach('Count') -Message 'each with its own count'

#───────────────────────────────────────────────────────────────────────────────
# Act
$scanned = @('starting', '3 passed, 1 failed', 'done' | Read-Tally -Separator ', ')

# Assert
Assert-Equal -Expected @('passed', 'failed') -Actual $scanned.Name `
    -Message 'Piped lines with no tally in them are skipped'

#───────────────────────────────────────────────────────────────────────────────
# Act
$logLine = @(Read-Tally -Text '3 warnings found')

# Assert
Assert-Equal -Expected @('warnings found') -Actual @($logLine.Name) `
    -Message 'but any line shaped like "<count> <name>" is read as a tally, whatever it meant'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$huge = @(Read-Tally -Text '99999999999 passed - 2 failed')

# Assert
Assert-Equal -Expected 99999999999 -Actual $huge[0].Count `
    -Message 'A count past what an int holds is read, not thrown on'
Assert-Equal -Expected 2 -Actual $huge[1].Count -Message 'and the entries after it are unaffected'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$tooBig = @(Read-Tally -Text '99999999999999999999999 passed - 2 failed')

# Assert
Assert-Equal -Expected @('failed') -Actual @($tooBig.Name) `
    -Message 'A count too large for any integer is skipped, not thrown on'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$negative = @(Read-Tally -Text '-4 passed')

# Assert
Assert-Equal -Expected (-4) -Actual $negative[0].Count -Message 'A negative count is read, since Add-Tally can make one'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$unicode = @(Read-Tally -Text "$([char]0x0663) passed - 1 failed")

# Assert
Assert-Equal -Expected @('failed') -Actual @($unicode.Name) `
    -Message 'A count written in non-ASCII digits is skipped, not thrown on'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$padded = @(Read-Tally -Text "  1 failed`r")

# Assert
Assert-Equal -Expected 'failed' -Actual $padded[0].Name `
    -Message 'Whitespace, including a stray carriage return, is not part of the name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - one text of several lines, a part of which runs across a line break
$multiLine = @(Read-Tally -Text "1 a - 2 b`n3 c - 4 d")

# Assert
Assert-Equal -Expected @('a', 'd') -Actual @($multiLine.Name) `
    -Message 'Only the parts that sit on one line are read from a text of several lines'
Assert-Equal -Expected @([long]1, [long]4) -Actual @($multiLine.ForEach('Count')) -Message 'with their counts'

#───────────────────────────────────────────────────────────────────────────────
# Act
$noSeparator = { Read-Tally -Text '1 passed' -Separator '' }

# Assert
Assert-Throws -ScriptBlock $noSeparator -MessageLike "*'Separator'*" -Message 'An empty separator is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - Format-Tally's own output, round-tripped back through Read-Tally
Clear-Tally
Add-Tally -Name 'passed' -Amount 5
Add-Tally -Name 'failed' -Amount 2

# Act
$roundTrip = @(Read-Tally -Text (Format-Tally))

# Assert
Assert-Equal -Expected @('passed', 'failed') -Actual $roundTrip.Name `
    -Message 'Read-Tally recovers the names Format-Tally printed'
Assert-Equal -Expected @(5, 2) -Actual $roundTrip.ForEach('Count') `
    -Message 'Read-Tally recovers the counts Format-Tally printed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the awkward counts and names that are allowed
Clear-Tally
Add-Tally -Name 'overdrawn' -Amount -3
Add-Tally -Name 'bytes' -Amount 5000000000
Add-Tally -Name 'two words'
Add-Tally -Name '3 passed'
Add-Tally -Name 'most' -Amount ([long]::MaxValue)

# Act
$awkward = @(Read-Tally -Text (Format-Tally))

# Assert
Assert-Equal -Expected @('overdrawn', 'bytes', 'two words', '3 passed', 'most') -Actual $awkward.Name `
    -Message 'Names with spaces, or that start with a number, come back unchanged'
Assert-Equal -Expected @(-3, 5000000000, 1, 1, [long]::MaxValue) -Actual $awkward.ForEach('Count') `
    -Message 'and so do negative and very large counts'
Clear-Tally

exit (Complete-TestRun)
