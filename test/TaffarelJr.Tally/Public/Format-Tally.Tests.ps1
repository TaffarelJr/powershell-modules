#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - nothing tallied and no -Name given
Assert-Equal -Expected '' -Actual (Format-Tally) -Message 'Format-Tally with nothing tallied and no -Name returns an empty string'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Add-Tally -Name 'passed' -Amount 3
Add-Tally -Name 'failed' -Amount 1

# Act / Assert - default separator, every tallied name in the order first added
Assert-Equal -Expected '3 passed - 1 failed' -Actual (Format-Tally) -Message 'Format-Tally with no -Name joins every tally in the order it was first added'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - an explicit -Name list
# controls both which names appear and their order
Assert-Equal -Expected '1 failed - 3 passed' -Actual (Format-Tally -Name @('failed', 'passed')) -Message 'Format-Tally -Name overrides the default order'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a name in the -Name list
# that was never tallied still appears, at zero
Assert-Equal -Expected '3 passed - 0 crashed' -Actual (Format-Tally -Name @('passed', 'crashed')) -Message 'Format-Tally -Name includes an untallied name at zero rather than skipping it'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - -Separator overrides the default join text
Assert-Equal -Expected '3 passed, 1 failed' -Actual (Format-Tally -Separator ', ') -Message 'Format-Tally -Separator overrides the default join text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a -Key isolates its own counters from the shared, global ones
Add-Tally -Name 'passed' -Key 'MyModule' -Amount 9

# Act / Assert
Assert-Equal -Expected '9 passed' -Actual (Format-Tally -Key 'MyModule') -Message 'Format-Tally -Key renders that namespace instead of the shared, global counters'
Assert-Equal -Expected '3 passed - 1 failed' -Actual (Format-Tally) -Message 'Format-Tally -Key leaves the shared, global counters untouched'

exit (Complete-TestRun)
