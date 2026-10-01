#Requires -Version 7.4
using namespace System.Runtime.CompilerServices

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$gatePath = Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Private/Get-ConsoleEncodingGate.ps1'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - twelve runspaces arriving together, before any gate exists
$runspaceIds = 1..12 | ForEach-Object -ThrottleLimit 12 -Parallel {
    . $using:gatePath
    [System.Runtime.CompilerServices.RuntimeHelpers]::GetHashCode((Get-ConsoleEncodingGate))
}

# Act
. $gatePath
$ownId = [RuntimeHelpers]::GetHashCode((Get-ConsoleEncodingGate))
$distinct = @($runspaceIds + $ownId | Sort-Object -Unique)

# Assert
Assert-Equal -Expected 1 -Actual $distinct.Count `
    -Message 'Every runspace gets the one gate, however they race to create it'

#───────────────────────────────────────────────────────────────────────────────
# Act
$first = Get-ConsoleEncodingGate
$second = Get-ConsoleEncodingGate

# Assert
Assert-That -Condition ([object]::ReferenceEquals($first, $second)) -Message 'Repeated calls return the same gate'

#───────────────────────────────────────────────────────────────────────────────
# Assert - nobody has taken the pin yet
Assert-Equal -Expected 0 -Actual $first.Depth -Message 'A new gate has no holders'
Assert-That -Condition ($null -eq $first.Original) -Message 'A new gate has no output encoding to restore'
Assert-That -Condition ($null -eq $first.OriginalInput) -Message 'and no input encoding to restore'

#───────────────────────────────────────────────────────────────────────────────
# Act
$slot = [AppDomain]::CurrentDomain.GetData('TaffarelJr.ProcessInvocation.ConsoleEncodingGate.v1')

# Assert
Assert-That -Condition ([object]::ReferenceEquals($first, $slot)) `
    -Message ('The record is kept in the AppDomain under a name' +
        ' that ends in the version of its shape, so two versions of the module do not share one')

exit (Complete-TestRun)
