#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force

# Complete-TestRun reads this file's own running tally,
# so every case here runs in a fresh child process instead of in-process -
# otherwise this file's own Assert-Equal/Assert-That calls below
# would be counted by the very call being tested.

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - no assertions made at all
$zeroScript = "Import-Module '$modulePath' -Force; exit (Complete-TestRun)"
$zeroOutput = @(& pwsh -NoProfile -NonInteractive -Command $zeroScript)
$zeroExitCode = $LASTEXITCODE

# Assert
Assert-That -Condition ($zeroOutput -contains '0 passed, 0 failed') -Message 'Zero assertions tally as 0 passed, 0 failed'
Assert-Equal -Expected 0 -Actual $zeroExitCode -Message 'Zero failures exits 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - only passing assertions
$passScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-That -Condition `$true -Message 'a'; " `
    + "Assert-That -Condition `$true -Message 'b'; " `
    + "exit (Complete-TestRun)"
$passOutput = @(& pwsh -NoProfile -NonInteractive -Command $passScript)
$passExitCode = $LASTEXITCODE

# Assert
Assert-That -Condition ($passOutput -contains '2 passed, 0 failed') -Message 'Two passes tally as 2 passed, 0 failed'
Assert-Equal -Expected 0 -Actual $passExitCode -Message 'No failures exits 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a mix, including failures
$mixedScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-That -Condition `$true -Message 'a'; " `
    + "Assert-That -Condition `$false -Message 'b'; " `
    + "Assert-That -Condition `$false -Message 'c'; " `
    + "exit (Complete-TestRun)"
$mixedOutput = @(& pwsh -NoProfile -NonInteractive -Command $mixedScript)
$mixedExitCode = $LASTEXITCODE

# Assert
Assert-That -Condition ($mixedOutput -contains '1 passed, 2 failed') -Message 'A mix of pass/fail tallies correctly'
Assert-Equal -Expected 2 -Actual $mixedExitCode -Message 'Complete-TestRun returns the failure count as the exit code'

exit (Complete-TestRun)
