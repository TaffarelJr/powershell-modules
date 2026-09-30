#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/New-TestFileResult.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Test-FileFailed.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a clean pass is not a failure
$clean = New-TestFileResult -Name 'x' -Passed 3

# Assert
Assert-Equal -Expected $false -Actual (Test-FileFailed -Result $clean) `
    -Message 'Exit 0, not crashed, nothing failed, is not a failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a non-zero exit is a failure
$failed = New-TestFileResult -Name 'x' -ExitCode 1 -Failed 1

# Assert
Assert-Equal -Expected $true -Actual (Test-FileFailed -Result $failed) -Message 'A non-zero exit counts as a failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a crash at exit 0 is still a failure
$crashedAtZero = New-TestFileResult -Name 'x' -Crashed

# Assert
Assert-Equal -Expected $true -Actual (Test-FileFailed -Result $crashedAtZero) `
    -Message 'A crash counts as a failure even at exit 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - failed cases reported by a file that exits 0
$liar = New-TestFileResult -Name 'x' -Passed 3 -Failed 2

# Assert
Assert-Equal -Expected $true -Actual (Test-FileFailed -Result $liar) `
    -Message 'A failed case counts as a failure even when the file exited 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a file stopped for running too long
$timedOut = New-TestFileResult -Name 'x' -Crashed -TimedOut -ExitCode 124

# Assert
Assert-Equal -Expected $true -Actual (Test-FileFailed -Result $timedOut) -Message 'A timed-out file is a failure'

exit (Complete-TestRun)
