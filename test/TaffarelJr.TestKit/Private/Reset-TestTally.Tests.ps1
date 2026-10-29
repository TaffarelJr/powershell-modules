#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'TestKitTestHelper.ps1')
$module = Get-Module TaffarelJr.TestKit

#───────────────────────────────────────────────────────────────────────────────
# Act
$seen = Invoke-WithTally -Passed 3 -Failed 2 -ScriptBlock {
    $held = & $module { Reset-TestTally }
    $tally = & $module { Get-TestTally }
    [PSCustomObject]@{
        Held = "$($held.Passed) passed, $($held.Failed) failed"
        Left = "$($tally.Passed) passed, $($tally.Failed) failed"
    }
}

# Assert
Assert-Equal -Expected '3 passed, 2 failed' -Actual $seen.Held -Message 'The counts the tally held are returned'
Assert-Equal -Expected '0 passed, 0 failed' -Actual $seen.Left -Message 'and the tally is left empty'

exit (Complete-TestRun)
