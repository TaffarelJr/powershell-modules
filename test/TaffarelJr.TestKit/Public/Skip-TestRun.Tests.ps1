#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot '..' 'TestKitTestHelper.ps1')

# Skip-TestRun reads this process's running tally, so every case runs against a
# tally set for the purpose.

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 0 -Failed 0 -ScriptBlock { Skip-TestRun -Reason 'no gh here' } })

# Assert
Assert-Equal -Expected @('skipped - no gh here', '', '0 passed, 0 failed') -Actual $lines `
    -Message 'A skip says why, then prints the tally a runner reads'
Assert-Equal -Expected 0 -Actual $script:code -Message 'and exits 0'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Invoke-WithTally -Passed 1 -Failed 0 -ScriptBlock { Skip-TestRun -Reason 'too late' } } `
    -MessageLike '*after assertions ran*' `
    -Message 'A skip after a passing assertion throws'
Assert-Throws -ScriptBlock { Invoke-WithTally -Passed 0 -Failed 1 -ScriptBlock { Skip-TestRun -Reason 'too late' } } `
    -MessageLike '*after assertions ran*' `
    -Message 'and so does one after a failing assertion'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$left = Invoke-WithTally -Passed 1 -Failed 0 -ScriptBlock {
    try {
        $null = Skip-TestRun -Reason 'too late'
    }
    catch {
        $null = $_
    }

    $tally = & (Get-Module TaffarelJr.TestKit) { Get-TestTally }
    "$($tally.Passed) passed, $($tally.Failed) failed"
}

# Assert
Assert-Equal -Expected '0 passed, 0 failed' -Actual $left `
    -Message 'Even a refused skip empties the tally, so the next file in the session starts clean'

exit (Complete-TestRun)
