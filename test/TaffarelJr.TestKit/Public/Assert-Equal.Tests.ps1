#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - equal values print an "ok" line and are a real pass,
# so this is safe to run in-process
$lines = Get-HostOutput { Assert-Equal -Expected 5 -Actual 5 -Message 'values match' }

# Assert
Assert-That -Condition ($lines[0] -like '*ok*values match*') -Message 'Equal values print an "ok" line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - unequal values print a "FAIL" line naming both values -
# this exact message format is never exercised by any other test in this repo,
# since every other test's Assert-Equal call is written to pass.
# Runs isolated in a fresh process:
# a deliberate mismatch is a real failure
# that would otherwise corrupt this file's own tally,
# since Assert-Equal calls Assert-That internally to record it.
$innerScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-Equal -Expected 'expected-value' -Actual 'actual-value' -Message 'values should match'; " `
    + "exit (Complete-TestRun)"
$innerOutput = @(& pwsh -NoProfile -NonInteractive -Command $innerScript)

# Assert
Assert-That -Condition ($innerOutput[0] -like '*FAIL*values should match*') -Message 'Unequal values print a "FAIL" line'
Assert-That -Condition ($innerOutput[0] -like '*expected-value*') -Message 'The failure message names the expected value'
Assert-That -Condition ($innerOutput[0] -like '*actual-value*') -Message 'The failure message names the actual value'

exit (Complete-TestRun)
