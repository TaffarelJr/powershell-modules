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
Add-Tally -Name 'passed' -Amount 3
Add-Tally -Name 'failed' -Amount 1

# Act
Clear-Tally -Name 'passed'

# Assert
Assert-Equal -Expected 0 -Actual (Get-Tally -Name 'passed') -Message 'Clear-Tally -Name resets just that name'
Assert-Equal -Expected 1 -Actual (Get-Tally -Name 'failed') -Message 'Clear-Tally -Name leaves other names untouched'
Assert-Equal -Expected @('failed') -Actual @((Get-Tally).Name) -Message 'and the cleared name is gone, not left at zero'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed'

# Act
Clear-Tally -Name 'neverAdded'

# Assert
Assert-Equal -Expected 1 -Actual (Get-Tally -Name 'passed') `
    -Message 'Clearing a name that was never added is a no-op, not an error'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed'
Add-Tally -Name 'failed'

# Act
Clear-Tally

# Assert
Assert-Equal -Expected 0 -Actual @(Get-Tally).Count -Message 'Clear-Tally with no -Name removes every tallied name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'a'
Add-Tally -Name 'b'
Add-Tally -Name 'c'

# Act
'a', 'c' | Clear-Tally

# Assert
Assert-Equal -Expected @('b') -Actual @((Get-Tally).Name) -Message 'Names piped in are each cleared'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'a'
Add-Tally -Name 'b'

# Act
Get-Tally | Clear-Tally

# Assert
Assert-Equal -Expected 0 -Actual @(Get-Tally).Count -Message 'Get-Tally output piped in clears each counter by its Name'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name '@{Extension=.txt}' -Amount 2
Add-Tally -Name 'System.Collections.Hashtable' -Amount 3

# Act
$noName = { [PSCustomObject]@{ Extension = '.txt' } | Clear-Tally }
$dictionary = { @{ Name = 'x' } | Clear-Tally }

# Assert
Assert-Throws -ScriptBlock $noName -MessageLike '*Name property*' `
    -Message 'A piped object with no Name property is refused, not cleared by its own text'
Assert-Throws -ScriptBlock $dictionary -MessageLike '*Name property*' -Message 'and so is a dictionary'
Assert-Equal -Expected '2 @{Extension=.txt} - 3 System.Collections.Hashtable' -Actual (Format-Tally) `
    -Message 'and the counters named like their text are untouched'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'kept'

# Act
$nullName = { Clear-Tally -Name $null }
$padded = { Clear-Tally -Name ' kept' }

# Assert
Assert-Throws -ScriptBlock $nullName -MessageLike '*one line*' `
    -Message 'A $null -Name is refused, like Add-Tally refuses it'
Assert-Throws -ScriptBlock $padded -MessageLike '*one line*' `
    -Message 'and so is a name Add-Tally could never have added'
Assert-Equal -Expected 1 -Actual (Get-Tally -Name 'kept') -Message 'and nothing was cleared'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Clear-Tally -Key 'MyModule'
Add-Tally -Name 'passed' -Amount 1
Add-Tally -Name 'passed' -Key 'MyModule' -Amount 4

# Act
Clear-Tally -Key 'MyModule'

# Assert
Assert-Equal -Expected 0 -Actual (Get-Tally -Name 'passed' -Key 'MyModule') `
    -Message 'Clear-Tally -Key with no -Name removes every name under that namespace'
Assert-Equal -Expected 1 -Actual (Get-Tally -Name 'passed') `
    -Message 'Clear-Tally -Key leaves the shared, global counters untouched'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'kept' -Amount 5

# Act
$nullKey = { Clear-Tally -Key $null }
$emptyKey = { Clear-Tally -Key '' }
$blankKey = { Clear-Tally -Key ' ' }

# Assert
Assert-Throws -ScriptBlock $nullKey -MessageLike "*'Key'*non-blank*" `
    -Message 'A $null -Key is refused rather than clearing the global counters'
Assert-Throws -ScriptBlock $emptyKey -MessageLike "*'Key'*non-blank*" -Message 'and so is an empty one'
Assert-Throws -ScriptBlock $blankKey -MessageLike "*'Key'*non-blank*" -Message 'and one of only whitespace'
Assert-Equal -Expected 5 -Actual (Get-Tally -Name 'kept') -Message 'and the global counter is untouched'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Add-Tally -Name 'x' -Key 'forgotten'
$keysBefore = & $module { (Get-TallyState).Keyed.Count }

# Act
Clear-Tally -Key 'forgotten'
$keysAfter = & $module { (Get-TallyState).Keyed.Count }

# Assert
Assert-Equal -Expected ($keysBefore - 1) -Actual $keysAfter `
    -Message 'Clearing a whole key forgets the key too, so made-up keys do not pile up'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Add-Tally -Name 'x' -Key 'emptied'
Add-Tally -Name 'y' -Key 'emptied'
$keysBefore = & $module { (Get-TallyState).Keyed.Count }

# Act
Clear-Tally -Name 'x' -Key 'emptied'
$keysBetween = & $module { (Get-TallyState).Keyed.Count }
Clear-Tally -Name 'y' -Key 'emptied'
$keysAfter = & $module { (Get-TallyState).Keyed.Count }

# Assert
Assert-Equal -Expected $keysBefore -Actual $keysBetween `
    -Message 'Clearing one of a key''s names by name keeps the key while it still has counters'
Assert-Equal -Expected ($keysBefore - 1) -Actual $keysAfter `
    -Message 'and clearing its last name forgets the key, as clearing the whole key does'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Clear-Tally
Add-Tally -Name 'passed' -Key 'MyModule'

# Act
Clear-Tally -Name 'passed' -Key 'neverUsed'
Clear-Tally -Key 'neverUsed'

# Assert
Assert-Equal -Expected 1 -Actual (Get-Tally -Name 'passed' -Key 'MyModule') `
    -Message 'Clearing under a key nothing used is a no-op'
Clear-Tally -Key 'MyModule'

exit (Complete-TestRun)
