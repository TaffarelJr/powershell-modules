#Requires -Version 7.4
using namespace System.Runtime.CompilerServices

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - twelve runspaces arriving together, before any tally exists
$runspaceIds = 1..12 | ForEach-Object -ThrottleLimit 12 -Parallel {
    Import-Module $using:modulePath
    $tally = & (Get-Module TaffarelJr.TestKit) { Get-TestTally }
    [System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($tally)
}

# Act - read before this file's own assertions start counting into it
Import-Module $modulePath -Force
$module = Get-Module TaffarelJr.TestKit
$first = & $module { Get-TestTally }
$ownId = [RuntimeHelpers]::GetHashCode($first)
$passedAtStart = $first.Passed
$failedAtStart = $first.Failed
$distinct = @($runspaceIds + $ownId | Sort-Object -Unique)

# Assert
Assert-Equal -Expected 1 -Actual $distinct.Count `
    -Message 'Every runspace gets the one tally, however they race to create it'
Assert-Equal -Expected 0 -Actual $passedAtStart -Message 'A new tally has no passes'
Assert-Equal -Expected 0 -Actual $failedAtStart -Message 'A new tally has no failures'

#───────────────────────────────────────────────────────────────────────────────
# Act
$second = & $module { Get-TestTally }

# Assert
Assert-That -Condition ([object]::ReferenceEquals($first, $second)) -Message 'Repeated calls return the same tally'

#───────────────────────────────────────────────────────────────────────────────
# Act
$stored = [AppDomain]::CurrentDomain.GetData('TaffarelJr.TestKit.Tally.v1')
$unversioned = [AppDomain]::CurrentDomain.GetData('TaffarelJr.TestKit.Tally')

# Assert
Assert-That -Condition ([object]::ReferenceEquals($first, $stored)) `
    -Message 'The tally is stored under a key naming the version of its shape, so a later shape cannot misread it'
Assert-That -Condition ($null -eq $unversioned) -Message 'and nothing is stored under the key without a version'

exit (Complete-TestRun)
