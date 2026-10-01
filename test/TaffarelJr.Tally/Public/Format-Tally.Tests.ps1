#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act / Assert - nothing tallied and no -Name given
Assert-Equal -Expected '' -Actual (Format-Tally) `
    -Message 'Format-Tally with nothing tallied and no -Name returns an empty string'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed' -Amount 3
Add-Tally -Name 'failed' -Amount 1

# Act / Assert - default separator, every tallied name in the order first added
Assert-Equal -Expected '3 passed - 1 failed' -Actual (Format-Tally) `
    -Message 'Format-Tally with no -Name joins every tally in the order it was first added'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - counters named like members of the dictionary that holds them
Clear-Tally
Add-Tally -Name 'a'
Add-Tally -Name 'Keys'
Add-Tally -Name 'Values'
Add-Tally -Name 'Count'

# Act / Assert
Assert-Equal -Expected '1 a - 1 Keys - 1 Values - 1 Count' -Actual (Format-Tally) `
    -Message 'Format-Tally with no -Name renders every counter, whatever its name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed' -Amount 3
Add-Tally -Name 'failed' -Amount 1

# Act / Assert - an explicit -Name list
# controls both which names appear and their order
Assert-Equal -Expected '1 failed - 3 passed' -Actual (Format-Tally -Name @('failed', 'passed')) `
    -Message 'Format-Tally -Name overrides the default order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed' -Amount 3

# Act / Assert - a name in the -Name list
# that was never tallied still appears, at zero
Assert-Equal -Expected '3 passed - 0 crashed' -Actual (Format-Tally -Name @('passed', 'crashed')) `
    -Message 'Format-Tally -Name includes an untallied name at zero rather than skipping it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'a' -Amount 4
Add-Tally -Name 'b' -Amount 2

# Act
$fromObjects = Format-Tally -Name (Get-Tally)
$fromNumber = Format-Tally -Name 7
$noName = { Format-Tally -Name ([PSCustomObject]@{ Extension = '.txt' }) }

# Assert
Assert-Equal -Expected '4 a - 2 b' -Actual $fromObjects `
    -Message 'Objects given as -Name are read by their Name property'
Assert-Equal -Expected '0 7' -Actual $fromNumber -Message 'and a number by its text'
Assert-Throws -ScriptBlock $noName -MessageLike '*Name property*' `
    -Message 'and an object with no Name property is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'a' -Amount 4
Add-Tally -Name 'b' -Amount 2

# Act
$pipedObjects = Get-Tally | Format-Tally
$pipedStrings = 'b', 'missing' | Format-Tally -Separator ', '
$pipedNothing = @() | Format-Tally
$filteredToNothing = Get-Tally | Where-Object Count -GT 100 | Format-Tally
$notPiped = Format-Tally

# Assert
Assert-Equal -Expected '4 a - 2 b' -Actual $pipedObjects `
    -Message 'Objects piped in are read by their Name property, into one line'
Assert-Equal -Expected '2 b, 0 missing' -Actual $pipedStrings `
    -Message 'and names piped in are rendered in the order given, one never added at zero'
Assert-Equal -Expected '' -Actual $pipedNothing -Message 'A pipeline that delivers nothing renders no counters'
Assert-Equal -Expected '' -Actual $filteredToNothing -Message 'so a filter that matches nothing renders nothing'
Assert-Equal -Expected '4 a - 2 b' -Actual $notPiped -Message 'while no pipeline at all renders every counter'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - counts read from text, which are not counters yet
Clear-Tally
$read = @(Read-Tally -Text '5 passed - 2 failed')

# Act
$beforeMerge = $read | Format-Tally
$read | Add-Tally
$afterMerge = $read | Format-Tally

# Assert
Assert-Equal -Expected '0 passed - 0 failed' -Actual $beforeMerge `
    -Message 'A piped object only names a counter: its own Count is not shown'
Assert-Equal -Expected '5 passed - 2 failed' -Actual $afterMerge `
    -Message 'so counts read from text show once Add-Tally has merged them in'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'Passed' -Amount 3

# Act / Assert
Assert-Equal -Expected '3 Passed' -Actual (Format-Tally -Name 'passed') `
    -Message 'A name is shown as first added, whatever case it was asked for in'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed' -Amount 3
Add-Tally -Name 'failed' -Amount 1

# Act / Assert - -Separator overrides the default join text
Assert-Equal -Expected '3 passed, 1 failed' -Actual (Format-Tally -Separator ', ') `
    -Message 'Format-Tally -Separator overrides the default join text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a -Key isolates its own counters from the shared, global ones
Clear-Tally
Clear-Tally -Key 'MyModule'
Add-Tally -Name 'passed' -Amount 3
Add-Tally -Name 'failed' -Amount 1
Add-Tally -Name 'passed' -Key 'MyModule' -Amount 9

# Act / Assert
Assert-Equal -Expected '9 passed' -Actual (Format-Tally -Key 'MyModule') `
    -Message 'Format-Tally -Key renders that namespace instead of the shared, global counters'
Assert-Equal -Expected '3 passed - 1 failed' -Actual (Format-Tally) `
    -Message 'Format-Tally -Key leaves the shared, global counters untouched'
Assert-Equal -Expected '' -Actual (Format-Tally -Key 'neverUsed') `
    -Message 'A key nothing used renders as an empty string'
Assert-Equal -Expected '0 passed' -Actual (Format-Tally -Name 'passed' -Key 'neverUsed') `
    -Message 'and a name asked for under it renders at zero'

# Act
Clear-Tally -Key 'MyModule'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed'

# Act
$nullKey = { Format-Tally -Key $null }
$blankKey = { Format-Tally -Key ' ' }

# Assert
Assert-Throws -ScriptBlock $nullKey -MessageLike "*'Key'*non-blank*" `
    -Message 'A $null -Key is refused rather than rendering the global counters'
Assert-Throws -ScriptBlock $blankKey -MessageLike "*'Key'*non-blank*" -Message 'and so is a -Key of only whitespace'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'a - b'
Add-Tally -Name 'c'

# Act
$containing = { Format-Tally }
$other = Format-Tally -Separator ' | '
$asked = { Format-Tally -Name 'a - b' }

# Assert
Assert-Throws -ScriptBlock $containing -MessageLike "*'1 a - b'*separator ' - '*" `
    -Message 'A name containing the separator is refused, since the line could not be read back'
Assert-Equal -Expected '1 a - b | 1 c' -Actual $other -Message 'A separator the names do not contain is fine'
Assert-Throws -ScriptBlock $asked -MessageLike "*'1 a - b'*separator*" `
    -Message 'The same holds for a name asked for by -Name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name '- b'

# Act
$atStart = { Format-Tally }

# Assert
Assert-Throws -ScriptBlock $atStart -MessageLike "*'1 - b'*separator*" `
    -Message 'A name that makes the separator together with its count is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'a -'
Add-Tally -Name 'c'

# Act
$acrossJoin = { Format-Tally }

# Assert
Assert-Throws -ScriptBlock $acrossJoin -MessageLike "*'1 a -'*separator*" `
    -Message 'A name that makes the separator across the join with the next entry is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed' -Amount 3
Add-Tally -Name 'failed' -Amount 1

# Act
$space = { Format-Tally -Separator ' ' }

# Assert
Assert-Throws -ScriptBlock $space -MessageLike "*'3 passed'*separator ' '*" `
    -Message 'A separator that also parts each count from its name is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'x' -Amount 10

# Act
$digit = { Format-Tally -Separator '0' }

# Assert
Assert-Throws -ScriptBlock $digit -MessageLike "*'10 x'*separator '0'*" `
    -Message 'A separator found inside a count is refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
$empty = { Format-Tally -Name '' }
$withNull = { Format-Tally -Name @('a', $null) }
$padded = { Format-Tally -Name ' x' }
$noSeparator = { Format-Tally -Separator '' }

# Assert
Assert-Throws -ScriptBlock $empty -MessageLike '*one line*' `
    -Message 'An empty -Name is refused, rather than rendering a part Read-Tally cannot read'
Assert-Throws -ScriptBlock $withNull -MessageLike '*one line*' -Message 'and so is a $null among several names'
Assert-Throws -ScriptBlock $padded -MessageLike '*one line*' -Message 'and a name Add-Tally could never have added'
Assert-Throws -ScriptBlock $noSeparator -MessageLike "*'Separator'*" -Message 'An empty separator is refused'

exit (Complete-TestRun)
