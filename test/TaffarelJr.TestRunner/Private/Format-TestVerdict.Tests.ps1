#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/New-TestFileResult.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Format-TestVerdict.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a clean pass
$passed = Format-TestVerdict -Result (New-TestFileResult -Name 'x' -Passed 5)

# Assert
Assert-Equal -Expected '✅ 5 passed' -Actual $passed -Message 'A clean run reports the passed count'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - real failures
$failed = Format-TestVerdict -Result (New-TestFileResult -Name 'x' -Passed 3 -Failed 2 -ExitCode 1)

# Assert
Assert-Equal -Expected '❌ 3 passed, 2 failed' -Actual $failed -Message 'A failing run reports both counts'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - failed cases in a file that nevertheless exited 0
$liar = Format-TestVerdict -Result (New-TestFileResult -Name 'x' -Passed 3 -Failed 2)

# Assert
Assert-Equal -Expected '❌ 3 passed, 2 failed' -Actual $liar `
    -Message 'A failed case is shown as a failure whatever the exit code says'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a crash takes priority over whatever counts happened to be captured
$crashed = Format-TestVerdict -Result (New-TestFileResult -Name 'x' -Crashed -ExitCode 134)

# Assert
Assert-Equal -Expected '💥 crashed (exit 134)' -Actual $crashed `
    -Message 'A crash reports as crashed, naming the exit code'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a file stopped for running too long, which is also a crash
$timedOut = Format-TestVerdict -Result (New-TestFileResult -Name 'x' -Crashed -TimedOut -ExitCode 124)

# Assert
Assert-Equal -Expected '⏱ timed out' -Actual $timedOut `
    -Message 'A timed-out file says so rather than only that it crashed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a file no process ran
$notStarted = Format-TestVerdict -Result (New-TestFileResult -Name 'x' -Crashed -NotStarted -ExitCode 127)

# Assert
Assert-Equal -Expected '💥 not started' -Actual $notStarted `
    -Message 'A file no process ran says so, without an exit code it never had'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a file that skipped itself
$skipped = Format-TestVerdict -Result (New-TestFileResult -Name 'x' -Skipped -SkipReason 'gh is not installed')

# Assert
Assert-Equal -Expected '⏭ skipped - gh is not installed' -Actual $skipped `
    -Message 'A skipped file says so, with its reason, not as a green pass'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a file whose checks run by other means
$allowedEmpty = Format-TestVerdict -Result (New-TestFileResult -Name 'x' -AllowedEmpty)

# Assert
Assert-Equal -Expected '✅ 0 passed (checks run by other means)' -Actual $allowedEmpty `
    -Message 'A file allowed to run no cases passes, with a note saying why'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every kind of result, as the caller that marks the line itself asks for it
$unmarked = @(
    @{ Result = (New-TestFileResult -Name 'x' -Passed 5); Expected = '5 passed' }
    @{ Result = (New-TestFileResult -Name 'x' -Passed 3 -Failed 2 -ExitCode 1); Expected = '3 passed, 2 failed' }
    @{ Result = (New-TestFileResult -Name 'x' -Crashed -ExitCode 134); Expected = 'crashed (exit 134)' }
    @{ Result = (New-TestFileResult -Name 'x' -Crashed -TimedOut -ExitCode 124); Expected = 'timed out' }
    @{ Result = (New-TestFileResult -Name 'x' -Crashed -NotStarted -ExitCode 127); Expected = 'not started' }
    @{
        Result   = (New-TestFileResult -Name 'x' -Skipped -SkipReason 'gh is not installed')
        Expected = 'skipped - gh is not installed'
    }
    @{
        Result   = (New-TestFileResult -Name 'x' -AllowedEmpty)
        Expected = '0 passed (checks run by other means)'
    }
)

# Act / Assert
foreach ($case in $unmarked) {
    Assert-Equal -Expected $case.Expected -Actual (Format-TestVerdict -Result $case.Result -WithoutMarker) `
        -Message "-WithoutMarker leaves the marker off '$($case.Expected)'"
}

exit (Complete-TestRun)
