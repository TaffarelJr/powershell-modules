#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot '..' 'TestKitTestHelper.ps1')
$module = Get-Module TaffarelJr.TestKit

#───────────────────────────────────────────────────────────────────────────────
# Act - against a tally set aside for the purpose, so this file's own is untouched
$counted = Invoke-WithTally -Passed 0 -Failed 0 -ScriptBlock {
    & $module {
        Add-TestResult -Passed $true
        Add-TestResult -Passed $true
        Add-TestResult -Passed $false
    }

    $tally = & $module { Get-TestTally }
    "$($tally.Passed) passed, $($tally.Failed) failed"
}

# Assert
Assert-Equal -Expected '2 passed, 1 failed' -Actual $counted `
    -Message 'Each passing case adds one to Passed, and each failing case one to Failed'

#───────────────────────────────────────────────────────────────────────────────
# Act - twelve runspaces adding at once
$added = Invoke-WithTally -Passed 0 -Failed 0 -ScriptBlock {
    1..12 | ForEach-Object -ThrottleLimit 12 -Parallel {
        Import-Module $using:modulePath
        & (Get-Module TaffarelJr.TestKit) {
            1..50 | ForEach-Object { Add-TestResult -Passed $true }
        }
    }

    $tally = & $module { Get-TestTally }
    $tally.Passed
}

# Assert
Assert-Equal -Expected 600 -Actual $added -Message 'Concurrent additions are all counted, none lost'

exit (Complete-TestRun)
