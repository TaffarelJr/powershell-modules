#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/New-TestFileResult.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Format-TestSummary.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$results = @(
    New-TestFileResult -Name 'a' -Passed 5
    New-TestFileResult -Name 'b' -Passed 3 -Failed 2
    New-TestFileResult -Name 'c' -Crashed
    New-TestFileResult -Name 'd' -Skipped -SkipReason 'not here'
)

# Act
$summary = Format-TestSummary -Results $results -Elapsed ([TimeSpan]::FromSeconds(75))

# Assert
Assert-Equal -Expected '4 file(s) - 8 passed - 2 failed - 1 crashed - 1 skipped - 1:15' -Actual $summary `
    -Message 'Reports the files, the summed counts, the crashes and skips, and the time as minutes:seconds'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - no results at all
$emptySummary = Format-TestSummary -Results @() -Elapsed ([TimeSpan]::Zero)

# Assert
Assert-Equal -Expected '0 file(s) - 0 passed - 0 failed - 0 crashed - 0 skipped - 0:00' -Actual $emptySummary `
    -Message 'An empty run still renders a complete, zeroed-out summary'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a file whose checks run by other means
$allowedSummary = Format-TestSummary -Results @(New-TestFileResult -Name 'e' -AllowedEmpty) -Elapsed ([TimeSpan]::Zero)

# Assert
Assert-Equal -Expected '1 file(s) - 0 passed - 0 failed - 0 crashed - 0 skipped - 0:00' -Actual $allowedSummary `
    -Message 'A file allowed to run no cases is neither crashed nor skipped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a run of more than an hour
$long = Format-TestSummary -Results @() -Elapsed ([TimeSpan]::FromSeconds(3725))

# Assert
Assert-That -Condition ($long -like '*- 62:05') `
    -Message 'The minutes keep counting past an hour instead of starting over'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - counts somebody else has in Tally, unkeyed and under their own key
Add-Tally -Name 'passed' -Amount 40
Add-Tally -Name 'mine' -Amount 3 -Key 'SomebodyElse'

# Act
$null = Format-TestSummary -Results $results -Elapsed ([TimeSpan]::FromSeconds(1))
$again = Format-TestSummary -Results $results -Elapsed ([TimeSpan]::FromSeconds(1))
$unkeyed = Format-Tally -Name 'passed'
$keyed = Format-Tally -Name 'mine' -Key 'SomebodyElse'

# Assert
Assert-Equal -Expected '4 file(s) - 8 passed - 2 failed - 1 crashed - 1 skipped - 0:01' -Actual $again `
    -Message 'A second call starts from zero rather than adding to the first'
Assert-Equal -Expected '40 passed' -Actual $unkeyed -Message 'The caller''s own unkeyed count is left alone'
Assert-Equal -Expected '3 mine' -Actual $keyed -Message 'So is a count under a key of its own'

exit (Complete-TestRun)
