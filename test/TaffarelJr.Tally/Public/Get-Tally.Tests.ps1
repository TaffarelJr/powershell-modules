#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force

# Arrange / Act / Assert - a name that was never tallied is zero, not an error
Assert-Equal -Expected 0 -Actual (Get-Tally -Name 'neverAdded') -Message 'Get-Tally -Name on an untallied name returns zero'

# Arrange
Add-Tally -Name 'passed' -Amount 3
Add-Tally -Name 'failed' -Amount 1

# Act / Assert
Assert-Equal -Expected 3 -Actual (Get-Tally -Name 'passed') -Message 'Get-Tally -Name returns the running count for that name'

# Act - every counter, with no -Name
$all = Get-Tally

# Assert
Assert-Equal -Expected 2 -Actual $all.Count -Message 'Get-Tally with no -Name returns one entry per tallied name'
Assert-Equal -Expected 'passed' -Actual $all[0].Name -Message 'Entries come back in the order each name was first added'
Assert-Equal -Expected 3 -Actual $all[0].Count -Message 'Each entry carries its running count'
Assert-Equal -Expected 'failed' -Actual $all[1].Name -Message 'The second-added name comes second'

# Act - clearing one name leaves the others alone
Clear-Tally -Name 'passed'

# Assert
Assert-Equal -Expected 0 -Actual (Get-Tally -Name 'passed') -Message 'Clear-Tally -Name resets just that name'
Assert-Equal -Expected 1 -Actual (Get-Tally -Name 'failed') -Message 'Clear-Tally -Name leaves other names untouched'

# Act - clearing a name that was never added is a no-op, not an error
Clear-Tally -Name 'neverAdded'

# Act - clearing with no -Name resets every counter
Add-Tally -Name 'passed'
Clear-Tally

# Assert
Assert-Equal -Expected 0 -Actual (Get-Tally).Count -Message 'Clear-Tally with no -Name removes every tallied name'

exit (Complete-TestRun)
