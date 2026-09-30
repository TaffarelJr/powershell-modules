#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Read-TestTally.ps1')

# Arrange / Act - a clean pass
$clean = Read-TestTally -Output @('some line', '5 passed, 0 failed') -ExitCode 0

# Assert
Assert-Equal -Expected 5 -Actual $clean.Passed -Message 'Reads the passed count'
Assert-Equal -Expected 0 -Actual $clean.Failed -Message 'Reads the failed count'
Assert-That -Condition (-not $clean.Crashed) -Message 'A clean exit with a matching tally is not a crash'

# Arrange / Act - real failures, not a crash
$failed = Read-TestTally -Output @('3 passed, 2 failed') -ExitCode 2

# Assert
Assert-Equal -Expected 2 -Actual $failed.Failed -Message 'Reads the failed count from a failing exit'
Assert-That -Condition (-not $failed.Crashed) -Message 'A non-zero exit that matches its own failed count is not a crash'

# Arrange / Act - no tally line at all (the file crashed before printing one)
$noTally = Read-TestTally -Output @('some unrelated error text') -ExitCode 1

# Assert
Assert-Equal -Expected 0 -Actual $noTally.Passed -Message 'No tally line reads as zero passed'
Assert-That -Condition $noTally.Crashed -Message 'Missing a tally line at all counts as a crash'

# Arrange / Act - a non-zero exit but the tally claims nothing failed
$phantom = Read-TestTally -Output @('4 passed, 0 failed') -ExitCode 1

# Assert
Assert-That -Condition $phantom.Crashed -Message 'A failing exit with zero reported failures is a crash, not a clean pass'

# Arrange / Act - empty output entirely
$empty = Read-TestTally -Output @() -ExitCode 1

# Assert
Assert-That -Condition $empty.Crashed -Message 'Empty output is treated as a crash'

exit (Complete-TestRun)
