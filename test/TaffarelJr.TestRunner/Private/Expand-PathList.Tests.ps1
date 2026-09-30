#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Expand-PathList.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - already-separate elements pass through unchanged
$already = Expand-PathList -Value @('A', 'B')
Assert-Equal -Expected 2 -Actual $already.Count -Message 'A real multi-element array is left alone'
Assert-Equal -Expected 'A' -Actual $already[0] -Message 'The first element is unchanged'
Assert-Equal -Expected 'B' -Actual $already[1] -Message 'The second element is unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - one comma-joined element splits into several
$joined = Expand-PathList -Value @('A,B')
Assert-Equal -Expected 2 -Actual $joined.Count -Message 'A single comma-joined element splits apart'
Assert-Equal -Expected 'A' -Actual $joined[0] -Message 'The first split part is correct'
Assert-Equal -Expected 'B' -Actual $joined[1] -Message 'The second split part is correct'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - whitespace around a split part is trimmed
$spaced = Expand-PathList -Value @('A, B , C')
Assert-Equal -Expected 3 -Actual $spaced.Count -Message 'Every part of a comma-joined element is kept'
Assert-Equal -Expected 'A' -Actual $spaced[0] -Message 'A part with no surrounding space is unaffected'
Assert-Equal -Expected 'B' -Actual $spaced[1] -Message 'Space on both sides of a part is trimmed'
Assert-Equal -Expected 'C' -Actual $spaced[2] -Message 'Space on only one side of a part is trimmed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an empty part is dropped, not kept as a blank entry
$trailing = Expand-PathList -Value @('A,,B')
Assert-Equal -Expected 2 -Actual $trailing.Count -Message 'An empty part between two commas is dropped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - an empty input returns an empty array, never $null
$empty = Expand-PathList -Value @()
Assert-Equal -Expected 0 -Actual $empty.Count -Message 'An empty input returns zero entries'
Assert-That -Condition ($empty -is [array]) -Message 'The empty result is still an array'

exit (Complete-TestRun)
