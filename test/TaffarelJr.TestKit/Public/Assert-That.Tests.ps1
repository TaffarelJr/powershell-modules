#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force

# Arrange / Act - a true condition prints an "ok" line.
# Safe to run in-process: a true condition is a real pass,
# so it doesn't corrupt this file's own tally.
$lines = Get-HostOutput { Assert-That -Condition $true -Message 'something worked' }

# Assert
Assert-Equal -Expected 1 -Actual $lines.Count -Message 'Assert-That prints exactly one line'
Assert-That -Condition ($lines[0] -like '*ok*something worked*') -Message 'A true condition prints an "ok" line with the message'

# Arrange / Act - a false condition prints a "FAIL" line and tallies correctly.
# Runs isolated in a fresh process: deliberately triggering a false condition
# would otherwise increment this file's own FailCount,
# since the counters are shared by everything running in the same process,
# output capture or not.
$innerScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-That -Condition `$false -Message 'something broke'; " `
    + "exit (Complete-TestRun)"
$innerOutput = @(& pwsh -NoProfile -NonInteractive -Command $innerScript)
$innerExitCode = $LASTEXITCODE

# Assert
Assert-That -Condition ($innerOutput[0] -like '*FAIL*something broke*') -Message 'A false condition prints a "FAIL" line with the message'
Assert-That -Condition ($innerOutput -contains '0 passed, 1 failed') -Message 'A single false condition tallies as 0 passed, 1 failed'
Assert-Equal -Expected 1 -Actual $innerExitCode -Message 'The process exits with the failure count'

# Arrange / Act - a mix of passes and failures tallies correctly
$mixedScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-That -Condition `$true -Message 'inner pass one'; " `
    + "Assert-That -Condition `$true -Message 'inner pass two'; " `
    + "Assert-That -Condition `$false -Message 'inner fail'; " `
    + "exit (Complete-TestRun)"
$mixedOutput = @(& pwsh -NoProfile -NonInteractive -Command $mixedScript)
$mixedExitCode = $LASTEXITCODE

# Assert
Assert-That -Condition ($mixedOutput -contains '2 passed, 1 failed') -Message 'Two passes and one failure tally correctly'
Assert-Equal -Expected 1 -Actual $mixedExitCode -Message 'The process exits with the failure count'

exit (Complete-TestRun)
