#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
$module = Get-Module TaffarelJr.Tally

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act / Assert - a name that was never tallied is zero, not an error
Assert-Equal -Expected 0 -Actual (Get-Tally -Name 'neverAdded') `
    -Message 'Get-Tally -Name on an untallied name returns zero'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed' -Amount 3
Add-Tally -Name 'failed' -Amount 1

# Act / Assert
Assert-Equal -Expected 3 -Actual (Get-Tally -Name 'passed') `
    -Message 'Get-Tally -Name returns the running count for that name'
Assert-Equal -Expected 3 -Actual (Get-Tally -Name 'PASSED') -Message 'and finds it whatever the case'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed' -Amount 3
Add-Tally -Name 'failed' -Amount 1

# Act - every counter, with no -Name
$all = Get-Tally

# Assert
Assert-Equal -Expected 2 -Actual $all.Count -Message 'Get-Tally with no -Name returns one entry per tallied name'
Assert-Equal -Expected 'passed' -Actual $all[0].Name -Message 'Entries come back in the order each name was first added'
Assert-Equal -Expected 3 -Actual $all[0].Count -Message 'Each entry carries its running count'
Assert-Equal -Expected 'failed' -Actual $all[1].Name -Message 'The second-added name comes second'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - counters named like members of the dictionary that holds them
Clear-Tally
Add-Tally -Name 'a'
Add-Tally -Name 'Keys'
Add-Tally -Name 'Values'
Add-Tally -Name 'Count'

# Act
$named = @(Get-Tally)

# Assert
Assert-Equal -Expected @('a', 'Keys', 'Values', 'Count') -Actual @($named.Name) `
    -Message 'Get-Tally with no -Name returns every counter, whatever its name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
$none = Get-Tally
Add-Tally -Name 'only'
$one = Get-Tally
$collected = @(Get-Tally)

# Assert
Assert-That -Condition ($null -eq $none) -Message 'With nothing tallied, nothing is written, so a bare capture is $null'
Assert-Equal -Expected 'only' -Actual $one.Name -Message 'With one counter, that counter itself is written'
Assert-Equal -Expected 1 -Actual $collected.Count -Message 'and wrapping the call in @() collects it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'a'
Add-Tally -Name 'b'

# Act
$piped = Get-Tally | Measure-Object

# Assert
Assert-Equal -Expected 2 -Actual $piped.Count `
    -Message 'Each counter is its own pipeline item, so the call pipes straight into another command'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed' -Amount 3

# Act - changing what came back
$copy = @(Get-Tally)
$copy[0].Count = 999

# Assert
Assert-Equal -Expected 3 -Actual (Get-Tally -Name 'passed') `
    -Message 'What Get-Tally returns is a copy, so changing it changes nothing in the tally'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'a' -Amount 2
Add-Tally -Name 'b' -Amount 5

# Act
$counts = 'b', 'a', 'neverAdded' | Get-Tally

# Assert
Assert-Equal -Expected @(5, 2, 0) -Actual @($counts) -Message 'Names piped in are each read, in the order given'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'a' -Amount 2

# Act
$counts = [PSCustomObject]@{ Name = 'a' } | Get-Tally

# Assert
Assert-Equal -Expected 2 -Actual $counts -Message 'An object piped in is read by its Name property'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name '@{Extension=.txt}' -Amount 2

# Act
$noName = { [PSCustomObject]@{ Extension = '.txt' } | Get-Tally }
$dictionary = { @{ Name = 'x' } | Get-Tally }

# Assert
Assert-Throws -ScriptBlock $noName -MessageLike '*Name property*' `
    -Message 'A piped object with no Name property is refused, not read by its own text'
Assert-Throws -ScriptBlock $dictionary -MessageLike '*Name property*' -Message 'and so is a dictionary'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally

# Act
$padded = { Get-Tally -Name ' x' }
$empty = { Get-Tally -Name '' }

# Assert
Assert-Throws -ScriptBlock $padded -MessageLike '*one line*' `
    -Message 'A name Add-Tally could never have added is refused, rather than read as zero'
Assert-Throws -ScriptBlock $empty -MessageLike '*one line*' -Message 'and so is an empty name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Clear-Tally -Key 'MyModule'
Add-Tally -Name 'passed' -Amount 1
Add-Tally -Name 'passed' -Key 'MyModule' -Amount 4

# Act / Assert
Assert-Equal -Expected 4 -Actual (Get-Tally -Name 'passed' -Key 'MyModule') `
    -Message 'Get-Tally -Key reads from that namespace instead of the shared, global counters'
Assert-Equal -Expected 1 -Actual (Get-Tally -Name 'passed') `
    -Message 'Get-Tally -Key leaves the shared, global counter of the same name untouched'
Assert-Equal -Expected 0 -Actual (Get-Tally -Name 'neverAdded' -Key 'MyModule') `
    -Message 'Get-Tally -Key on an untallied name returns zero, same as the global counters'

# Act
Clear-Tally -Key 'MyModule'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed'

# Act
$nullKey = { Get-Tally -Name 'passed' -Key $null }
$blankKey = { Get-Tally -Key ' ' }

# Assert
Assert-Throws -ScriptBlock $nullKey -MessageLike "*'Key'*non-blank*" `
    -Message 'A $null -Key is refused rather than reading the global counters'
Assert-Throws -ScriptBlock $blankKey -MessageLike "*'Key'*non-blank*" -Message 'and so is a -Key of only whitespace'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally -Key 'neverUsed'
$keysBefore = & $module { (Get-TallyState).Keyed.Count }

# Act
$name = Get-Tally -Name 'x' -Key 'neverUsed'
$all = @(Get-Tally -Key 'neverUsed')
$keysAfter = & $module { (Get-TallyState).Keyed.Count }

# Assert
Assert-Equal -Expected 0 -Actual $name -Message 'Reading a name under a key nothing used gives zero'
Assert-Equal -Expected 0 -Actual $all.Count -Message 'and reading every counter gives nothing to collect'
Assert-Equal -Expected $keysBefore -Actual $keysAfter `
    -Message 'and neither leaves an empty set of counters behind for the key'

exit (Complete-TestRun)
