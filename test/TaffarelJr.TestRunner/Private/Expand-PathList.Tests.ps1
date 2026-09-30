#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Expand-PathList.ps1')
. (Join-Path $PSScriptRoot '..' 'TestRunnerTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - already-separate elements pass through unchanged
$already = @(Expand-PathList -Value @('A', 'B'))

# Assert
Assert-Equal -Expected 2 -Actual $already.Count -Message 'A real multi-element array is left alone'
Assert-Equal -Expected 'A' -Actual $already[0] -Message 'The first element is unchanged'
Assert-Equal -Expected 'B' -Actual $already[1] -Message 'The second element is unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - one comma-joined element splits into several
$joined = @(Expand-PathList -Value @('A,B'))

# Assert
Assert-Equal -Expected 2 -Actual $joined.Count -Message 'A single comma-joined element splits apart'
Assert-Equal -Expected 'A' -Actual $joined[0] -Message 'The first split part is correct'
Assert-Equal -Expected 'B' -Actual $joined[1] -Message 'The second split part is correct'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - whitespace around a split part is trimmed
$spaced = @(Expand-PathList -Value @('A, B , C'))

# Assert
Assert-Equal -Expected 3 -Actual $spaced.Count -Message 'Every part of a comma-joined element is kept'
Assert-Equal -Expected 'A' -Actual $spaced[0] -Message 'A part with no surrounding space is unaffected'
Assert-Equal -Expected 'B' -Actual $spaced[1] -Message 'Space on both sides of a part is trimmed'
Assert-Equal -Expected 'C' -Actual $spaced[2] -Message 'Space on only one side of a part is trimmed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an empty part is dropped, not kept as a blank entry
$trailing = @(Expand-PathList -Value @('A,,B'))

# Assert
Assert-Equal -Expected 2 -Actual $trailing.Count -Message 'An empty part between two commas is dropped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - blank entries are dropped
$blank = @(Expand-PathList -Value @('A', '', '  ', 'B'))

# Assert
Assert-Equal -Expected 'A|B' -Actual ($blank -join '|') -Message 'An empty or whitespace-only entry is dropped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder whose own name has a comma in it, beside two that do not exist
$sandbox = New-TestRunnerSandbox
$withComma = Join-Path $sandbox 'Doe, John'
New-Item -ItemType Directory -Path $withComma | Out-Null

# Act
$whole = @(Expand-PathList -Value @($withComma))
$mixed = @(Expand-PathList -Value @($withComma, 'A,B'))

# Assert
Assert-Equal -Expected 1 -Actual $whole.Count -Message 'A folder with a comma in its name is one entry, not two'
Assert-Equal -Expected $withComma -Actual $whole[0] -Message 'and it comes back exactly as given'
Assert-Equal -Expected 3 -Actual $mixed.Count `
    -Message 'A folder with a comma beside a comma-joined list: the folder stays whole, the list splits'
Assert-Equal -Expected $withComma -Actual $mixed[0] -Message 'The folder is still the first entry'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - one entry comes back as that entry
Assert-Equal -Expected 'A' -Actual (Expand-PathList -Value @('A')) -Message 'A single entry comes back as that entry'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an empty input writes nothing
$empty = @(Expand-PathList -Value @())

# Assert
Assert-Equal -Expected 0 -Actual $empty.Count `
    -Message 'An empty input returns zero entries, so @() collects an empty array'
Assert-That -Condition ($null -eq (Expand-PathList -Value @())) -Message 'and a bare capture is $null'

# Cleanup

Remove-TestRunnerSandbox -Path $sandbox

exit (Complete-TestRun)
