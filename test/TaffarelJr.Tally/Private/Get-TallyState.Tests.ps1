#Requires -Version 7.4
using namespace System.Runtime.CompilerServices

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$statePath = Join-Path $repoRoot 'src/TaffarelJr.Tally/Private/Get-TallyState.ps1'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - twelve runspaces arriving together, before any state exists
$runspaceIds = 1..12 | ForEach-Object -ThrottleLimit 12 -TimeoutSeconds 120 -Parallel {
    . $using:statePath
    [System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode((Get-TallyState))
}

# Act
. $statePath
$ownId = [RuntimeHelpers]::GetHashCode((Get-TallyState))
$distinct = @($runspaceIds + $ownId | Sort-Object -Unique)

# Assert
Assert-Equal -Expected 1 -Actual $distinct.Count `
    -Message 'Every runspace gets the one state, however they race to create it'

#───────────────────────────────────────────────────────────────────────────────
# Act
$state = Get-TallyState
$stored = [AppDomain]::CurrentDomain.GetData('TaffarelJr.Tally.State.v1')

# Assert
Assert-That -Condition ([object]::ReferenceEquals($state, $stored)) `
    -Message 'The state is stored under a key naming the version of its shape, so a later shape cannot misread it'

#───────────────────────────────────────────────────────────────────────────────
# Act
$first = Get-TallyState
$second = Get-TallyState

# Assert
Assert-That -Condition ([object]::ReferenceEquals($first, $second)) -Message 'Repeated calls return the same state'
Assert-Equal -Expected 0 -Actual $first.Global.Count -Message 'A new state has no global counters'
Assert-Equal -Expected 0 -Actual $first.Keyed.Count -Message 'and no keyed ones'

exit (Complete-TestRun)
