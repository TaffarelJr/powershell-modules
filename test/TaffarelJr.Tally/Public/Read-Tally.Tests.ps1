#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the default separator, one entry
$one = Read-Tally -Text '3 passed'

# Assert
Assert-Equal -Expected 1 -Actual $one.Count -Message 'A single entry parses to one result'
Assert-Equal -Expected 'passed' -Actual $one[0].Name -Message 'The name is read from the entry'
Assert-Equal -Expected 3 -Actual $one[0].Count -Message 'The count is read from the entry'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the default separator, several entries
$several = Read-Tally -Text '3 passed - 1 failed - 0 crashed'

# Assert
Assert-Equal -Expected 3 -Actual $several.Count -Message 'Every entry is parsed'
Assert-Equal -Expected @('passed', 'failed', 'crashed') -Actual $several.Name -Message 'Names come back in the order they appear'

# .ForEach('Count'), not bare .Count - the array's own Count property
# shadows member-enumeration of each entry's Count property otherwise.
Assert-Equal -Expected @(3, 1, 0) -Actual $several.ForEach('Count') -Message 'Counts come back in the order they appear'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Separator must match whatever produced the text
$commaSeparated = Read-Tally -Text '3 passed, 1 failed' -Separator ', '
Assert-Equal -Expected @('passed', 'failed') -Actual $commaSeparated.Name -Message '-Separator parses a non-default join correctly'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a part that isn't "<count> <name>" is skipped, not thrown
$withJunk = Read-Tally -Text '3 passed - not a tally - 1 failed'
Assert-Equal -Expected @('passed', 'failed') -Actual $withJunk.Name -Message 'A malformed part is skipped rather than breaking the whole parse'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - empty text parses to no entries at all, not an error
$empty = Read-Tally -Text ''
Assert-Equal -Expected 0 -Actual $empty.Count -Message 'Empty text returns zero entries'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - Format-Tally's own output, round-tripped back through Read-Tally
Add-Tally -Name 'passed' -Amount 5
Add-Tally -Name 'failed' -Amount 2

# Act
$roundTrip = Read-Tally -Text (Format-Tally)

# Assert
Assert-Equal -Expected @('passed', 'failed') -Actual $roundTrip.Name -Message 'Read-Tally recovers the names Format-Tally printed'
Assert-Equal -Expected @(5, 2) -Actual $roundTrip.ForEach('Count') -Message 'Read-Tally recovers the counts Format-Tally printed'

exit (Complete-TestRun)
