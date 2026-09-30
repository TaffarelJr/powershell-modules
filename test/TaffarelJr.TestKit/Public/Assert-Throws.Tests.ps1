#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a script block that throws
# prints an "ok" line and is a real pass, so this is safe to run in-process
$lines = Get-HostOutput { Assert-Throws -ScriptBlock { throw 'boom' } -Message 'it throws' }

# Assert
Assert-That -Condition ($lines[0] -like '*ok*it throws*') -Message 'A throwing script block prints an "ok" line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a script block that does NOT throw prints a "FAIL" line -
# untested anywhere else in this repo today,
# since nothing else calls Assert-Throws at all.
# Runs isolated in a fresh process:
# a deliberate non-throw is a real failure
# that would otherwise corrupt this file's own tally,
# since Assert-Throws calls Assert-That internally to record it.
$innerScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-Throws -ScriptBlock { 'no exception here' } -Message 'it should throw'; " `
    + "exit (Complete-TestRun)"
$innerOutput = @(& pwsh -NoProfile -NonInteractive -Command $innerScript)

# Assert
Assert-That -Condition ($innerOutput[0] -like '*FAIL*it should throw*') -Message 'A non-throwing script block prints a "FAIL" line'
Assert-That -Condition ($innerOutput[0] -like '*did not throw*') -Message 'The failure message says the block did not throw'

exit (Complete-TestRun)
