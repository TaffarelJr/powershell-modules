#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Format-TestSummary.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$results = @(
    [PSCustomObject]@{ Passed = 5; Failed = 0; Crashed = $false }
    [PSCustomObject]@{ Passed = 3; Failed = 2; Crashed = $false }
    [PSCustomObject]@{ Passed = 0; Failed = 0; Crashed = $true }
)

# Act
$summary = Format-TestSummary -Results $results -Elapsed ([TimeSpan]::FromSeconds(75))

# Assert
Assert-That -Condition ($summary -like '3 file(s)*') -Message 'Reports the number of files'
Assert-That -Condition ($summary -like '*8 passed*') -Message 'Sums the passed counts across every file'
Assert-That -Condition ($summary -like '*2 failed*') -Message 'Sums the failed counts across every file'
Assert-That -Condition ($summary -like '*1 crashed*') -Message 'Counts how many files crashed'
Assert-That -Condition ($summary -like '*1:15*') -Message 'Renders the elapsed time as minutes:seconds'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - no results at all
$emptySummary = Format-TestSummary -Results @() -Elapsed ([TimeSpan]::Zero)

# Assert
Assert-That -Condition ($emptySummary -like '0 file(s)*0 passed*0 failed*0 crashed*') -Message 'An empty run still renders a complete, zeroed-out summary'

exit (Complete-TestRun)
