#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Read-TestTally.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a clean pass
$clean = Read-TestTally -Output @('some line', '5 passed, 0 failed') -ExitCode 0

# Assert
Assert-Equal -Expected 5 -Actual $clean.Passed -Message 'Reads the passed count'
Assert-Equal -Expected 0 -Actual $clean.Failed -Message 'Reads the failed count'
Assert-That -Condition (-not $clean.Crashed) -Message 'A clean exit with a matching tally is not a crash'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - real failures, not a crash
$failed = Read-TestTally -Output @('3 passed, 2 failed') -ExitCode 2

# Assert
Assert-Equal -Expected 2 -Actual $failed.Failed -Message 'Reads the failed count from a failing exit'
Assert-That -Condition (-not $failed.Crashed) `
    -Message 'A non-zero exit that matches its own failed count is not a crash'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - no tally line at all (the file crashed before printing one)
$noTally = Read-TestTally -Output @('some unrelated error text') -ExitCode 1

# Assert
Assert-Equal -Expected 0 -Actual $noTally.Passed -Message 'No tally line reads as zero passed'
Assert-That -Condition $noTally.Crashed -Message 'Missing a tally line at all counts as a crash'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a non-zero exit but the tally claims nothing failed
$phantom = Read-TestTally -Output @('4 passed, 0 failed') -ExitCode 1

# Assert
Assert-That -Condition $phantom.Crashed `
    -Message 'A failing exit with zero reported failures is a crash, not a clean pass'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - two lines shaped like a tally, the file's own coming last
$twoLines = Read-TestTally -Output @('9 passed, 9 failed', 'chatter', '5 passed, 1 failed', 'more chatter') -ExitCode 1

# Assert
Assert-Equal -Expected 5 -Actual $twoLines.Passed `
    -Message 'The last tally-shaped line is the file''s own, not an earlier one'
Assert-Equal -Expected 1 -Actual $twoLines.Failed -Message 'and its failed count is the one read'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - empty output entirely
$empty = Read-TestTally -Output @() -ExitCode 1

# Assert
Assert-That -Condition $empty.Crashed -Message 'Empty output is treated as a crash'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a tally that counts no case at all, at exit 0
$noCases = Read-TestTally -Output @('No assertions ran.', '0 passed, 0 failed') -ExitCode 0

# Assert
Assert-Equal -Expected $true -Actual $noCases.Crashed `
    -Message 'A file whose tally counts no case is a crash, not a pass'
Assert-Equal -Expected $false -Actual $noCases.Skipped -Message 'and is not skipped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the lines Skip-TestRun prints, at exit 0
$skipped = Read-TestTally -Output @('skipped - gh is not installed', '', '0 passed, 0 failed') -ExitCode 0

# Assert
Assert-Equal -Expected $true -Actual $skipped.Skipped -Message 'A skip line before a tally of no cases is a skip'
Assert-Equal -Expected 'gh is not installed' -Actual $skipped.SkipReason -Message 'with the reason the file gave'
Assert-Equal -Expected $false -Actual $skipped.Crashed -Message 'and is not a crash'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a skip line that does not come before the tally
$lateSkip = Read-TestTally -Output @('0 passed, 0 failed', 'skipped - too late') -ExitCode 0

# Assert
Assert-Equal -Expected $false -Actual $lateSkip.Skipped -Message 'A skip line after the tally is not a skip'
Assert-Equal -Expected $true -Actual $lateSkip.Crashed -Message 'and the tally of no cases is a crash'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a skip that exits non-zero
$failedSkip = Read-TestTally -Output @('skipped - reason', '0 passed, 0 failed') -ExitCode 1

# Assert
Assert-Equal -Expected $true -Actual $failedSkip.Crashed -Message 'A skip that exits non-zero is a crash'
Assert-Equal -Expected $false -Actual $failedSkip.Skipped -Message 'not a skip'
Assert-Equal -Expected '' -Actual $failedSkip.SkipReason -Message 'and carries no reason'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a line shaped like a skip in a file whose cases ran
$ranCases = Read-TestTally -Output @('skipped - one case', '3 passed, 0 failed') -ExitCode 0

# Assert
Assert-Equal -Expected $false -Actual $ranCases.Skipped `
    -Message 'A file whose cases ran is not skipped, whatever it printed'
Assert-Equal -Expected $false -Actual $ranCases.Crashed -Message 'and passes'
Assert-Equal -Expected '' -Actual $clean.SkipReason -Message 'A file that is not skipped carries no reason'
Assert-Equal -Expected $false -Actual $clean.AllowedEmpty -Message 'and is not marked as allowed empty'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the lines Complete-TestRun -AllowEmpty prints, at exit 0
$allowed = Read-TestTally -Output @('', 'allowed empty - checks run by other means', '0 passed, 0 failed') -ExitCode 0

# Assert
Assert-Equal -Expected $false -Actual $allowed.Crashed `
    -Message 'A tally of no cases after the allowed-empty line is a pass, not a crash'
Assert-Equal -Expected $true -Actual $allowed.AllowedEmpty -Message 'and is marked as allowed empty'
Assert-Equal -Expected $false -Actual $allowed.Skipped -Message 'not as skipped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the allowed-empty line with a non-zero exit
$allowedFailing = Read-TestTally -Output @('allowed empty - checks run by other means', '0 passed, 0 failed') `
    -ExitCode 1

# Assert
Assert-Equal -Expected $true -Actual $allowedFailing.Crashed `
    -Message 'The allowed-empty line does not excuse a non-zero exit'
Assert-Equal -Expected $false -Actual $allowedFailing.AllowedEmpty -Message 'which is not marked as allowed empty'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a line that only resembles the allowed-empty one
$lookalike = Read-TestTally -Output @('Allowed Empty - checks run by other means', '0 passed, 0 failed') -ExitCode 0

# Assert
Assert-Equal -Expected $true -Actual $lookalike.Crashed `
    -Message 'Only the exact allowed-empty line excuses a tally of no cases'

exit (Complete-TestRun)
