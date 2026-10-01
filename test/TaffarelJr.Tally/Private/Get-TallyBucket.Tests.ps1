#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.Tally/Private/Get-TallyState.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.Tally/Private/Get-TallyBucket.ps1')

$state = Get-TallyState

#───────────────────────────────────────────────────────────────────────────────
# Act
$omitted = Get-TallyBucket
$null_ = Get-TallyBucket -Key $null
$empty = Get-TallyBucket -Key ''

# Assert
Assert-That -Condition ([object]::ReferenceEquals($state.Global, $omitted)) `
    -Message 'No key resolves to the global counters'
Assert-That -Condition ([object]::ReferenceEquals($state.Global, $null_)) -Message 'and so does $null'
Assert-That -Condition ([object]::ReferenceEquals($state.Global, $empty)) -Message 'and so does an empty string'

#───────────────────────────────────────────────────────────────────────────────
# Act
$missing = Get-TallyBucket -Key 'MyModule'

# Assert
Assert-That -Condition ($null -eq $missing) `
    -Message 'A key with no counters resolves to nothing, rather than a new empty set'
Assert-Equal -Expected 0 -Actual $state.Keyed.Count -Message 'and the lookup leaves nothing behind'

#───────────────────────────────────────────────────────────────────────────────
# Act
$created = Get-TallyBucket -Key 'MyModule' -Create
$again = Get-TallyBucket -Key 'MyModule'
$mixedCase = Get-TallyBucket -Key 'MYMODULE'

# Assert
Assert-That -Condition ($null -ne $created) -Message '-Create makes the key''s counters'
Assert-That -Condition ([object]::ReferenceEquals($created, $again)) -Message 'and later lookups find the same ones'
Assert-That -Condition ([object]::ReferenceEquals($created, $mixedCase)) -Message 'whatever the case of the key'
Assert-That -Condition (-not [object]::ReferenceEquals($state.Global, $created)) `
    -Message 'which are not the global ones'

#───────────────────────────────────────────────────────────────────────────────
# Act
$reused = Get-TallyBucket -Key 'MyModule' -Create

# Assert
Assert-That -Condition ([object]::ReferenceEquals($created, $reused)) `
    -Message '-Create on a key that already has counters returns them, not new ones'

exit (Complete-TestRun)
