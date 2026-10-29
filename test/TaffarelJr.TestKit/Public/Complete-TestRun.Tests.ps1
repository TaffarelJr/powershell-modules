#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot '..' 'TestKitTestHelper.ps1')

# Complete-TestRun reads this process's running tally, so the first cases run
# in a fresh child process - otherwise this file's own assertions would be
# counted by the very call being tested - which also shows the real exit code.

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no assertions made at all
$zeroScript = "Import-Module '$modulePath' -Force; exit (Complete-TestRun)"

# Act
$zeroOutput = @(& pwsh -NoProfile -NonInteractive -Command $zeroScript)
$zeroExitCode = $LASTEXITCODE

# Assert
Assert-ThatOrThrow -Condition ($zeroOutput -contains '0 passed, 0 failed') `
    -Message 'Zero assertions still print the tally'
Assert-That -Condition (($zeroOutput -join "`n") -like '*No assertions ran*Skip-TestRun*-AllowEmpty*') `
    -Message 'The output says no assertions ran, and what to use if that was on purpose'
Assert-ThatOrThrow -Condition (1 -eq $zeroExitCode) -Message 'A file that asserted nothing fails'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - only passing assertions
$passScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-That -Condition `$true -Message 'a'; " `
    + "Assert-That -Condition `$true -Message 'b'; " `
    + "exit (Complete-TestRun)"

# Act
$passOutput = @(& pwsh -NoProfile -NonInteractive -Command $passScript)
$passExitCode = $LASTEXITCODE

# Assert
Assert-ThatOrThrow -Condition ($passOutput -contains '2 passed, 0 failed') `
    -Message 'Two passes tally as 2 passed, 0 failed'
Assert-ThatOrThrow -Condition (0 -eq $passExitCode) -Message 'No failures exits 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a mix, including failures
$mixedScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-That -Condition `$true -Message 'a'; " `
    + "Assert-That -Condition `$false -Message 'b'; " `
    + "Assert-That -Condition `$false -Message 'c'; " `
    + "exit (Complete-TestRun)"

# Act
$mixedOutput = @(& pwsh -NoProfile -NonInteractive -Command $mixedScript)
$mixedExitCode = $LASTEXITCODE

# Assert
Assert-ThatOrThrow -Condition ($mixedOutput -contains '1 passed, 2 failed') `
    -Message 'A mix of pass/fail tallies correctly'
Assert-ThatOrThrow -Condition (2 -eq $mixedExitCode) `
    -Message 'Complete-TestRun returns the failure count as the exit code'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - more failures than an exit status can hold
$manyScript = "Import-Module '$modulePath' -Force; " `
    + "1..300 | ForEach-Object { Assert-That -Condition `$false -Message 'x' } | Out-Null; " `
    + "exit (Complete-TestRun)"

# Act
$manyOutput = @(& pwsh -NoProfile -NonInteractive -Command $manyScript)
$manyExitCode = $LASTEXITCODE

# Assert
Assert-ThatOrThrow -Condition ($manyOutput -contains '0 passed, 300 failed') `
    -Message 'The tally still shows the true count'
Assert-ThatOrThrow -Condition (255 -eq $manyExitCode) `
    -Message 'The exit code is capped at 255, since a POSIX status would wrap 256 to success'

$sandbox = (New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) "complete-$([Guid]::NewGuid())")).FullName
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - files run one after another in one session, as at a prompt
    $passFile = Join-Path $sandbox 'Pass.Tests.ps1'
    $failFile = Join-Path $sandbox 'Fail.Tests.ps1'
    $emptyFile = Join-Path $sandbox 'Empty.Tests.ps1'
    Set-Content -LiteralPath $passFile `
        -Value "Import-Module '$modulePath' -Force; Assert-That -Condition `$true -Message 'p'; exit (Complete-TestRun)"
    Set-Content -LiteralPath $failFile `
        -Value "Import-Module '$modulePath' -Force; Assert-That -Condition `$false -Message 'f'; exit (Complete-TestRun)"
    Set-Content -LiteralPath $emptyFile -Value "Import-Module '$modulePath' -Force; exit (Complete-TestRun)"
    $passThenEmpty = "& '$passFile'; `$first = `$LASTEXITCODE; & '$emptyFile'; 'exit codes ' + `$first + ' ' + `$LASTEXITCODE"
    $failThenPass = "& '$failFile'; `$first = `$LASTEXITCODE; & '$passFile'; 'exit codes ' + `$first + ' ' + `$LASTEXITCODE"

    # Act
    $passThenEmptyOutput = @(& pwsh -NoProfile -NonInteractive -Command $passThenEmpty)
    $failThenPassOutput = @(& pwsh -NoProfile -NonInteractive -Command $failThenPass)

    # Assert
    Assert-ThatOrThrow -Condition ($passThenEmptyOutput -contains '0 passed, 0 failed') `
        -Message 'The second file in a session starts from an empty tally'
    Assert-ThatOrThrow -Condition ($passThenEmptyOutput[-1] -ceq 'exit codes 0 1') `
        -Message 'so a file with no assertions fails even after one that passed'
    Assert-ThatOrThrow -Condition ($failThenPassOutput -contains '1 passed, 0 failed') `
        -Message 'A file after a failing one counts only its own cases'
    Assert-ThatOrThrow -Condition ($failThenPassOutput[-1] -ceq 'exit codes 1 0') `
        -Message 'so a clean file passes even after one that failed'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

# The same cases again in this process, against a tally set for the purpose:
# slower to reason about but cheaper to run, and visible to coverage.

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 0 -Failed 0 -ScriptBlock { Complete-TestRun } })

# Assert
Assert-Equal -Expected 3 -Actual $lines.Count -Message 'An empty tally prints itself, then says why that fails'
Assert-Equal -Expected '0 passed, 0 failed' -Actual $lines[1] -Message 'The tally line is the usual one'
Assert-That -Condition ($lines[2] -like 'No assertions ran.*Skip-TestRun*-AllowEmpty*') `
    -Message 'The explanation names both ways to say it is on purpose'
Assert-Equal -Expected 1 -Actual $script:code -Message 'and the exit code is 1'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 0 -Failed 0 -ScriptBlock { Complete-TestRun -AllowEmpty } })

# Assert
Assert-Equal -Expected @('', 'allowed empty - checks run by other means', '0 passed, 0 failed') -Actual $lines `
    -Message '-AllowEmpty accepts a file that made no assertions, marking it so just before the tally line'
Assert-Equal -Expected 0 -Actual $script:code -Message 'and exits 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 0 -Failed 2 -ScriptBlock { Complete-TestRun -AllowEmpty } })

# Assert
Assert-Equal -Expected @('', '0 passed, 2 failed') -Actual $lines -Message '-AllowEmpty with failures prints no marker'
Assert-Equal -Expected 2 -Actual $script:code -Message 'and never excuses a failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 2 -Failed 0 -ScriptBlock { Complete-TestRun -AllowEmpty } })

# Assert
Assert-Equal -Expected @('', '2 passed, 0 failed') -Actual $lines `
    -Message '-AllowEmpty after assertions ran prints no marker'
Assert-Equal -Expected 0 -Actual $script:code -Message 'and exits 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 2 -Failed 0 -ScriptBlock { Complete-TestRun } })

# Assert
Assert-Equal -Expected @('', '2 passed, 0 failed') -Actual $lines -Message 'A clean tally prints just itself'
Assert-Equal -Expected 0 -Actual $script:code -Message 'and the exit code is 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 1 -Failed 2 -ScriptBlock { Complete-TestRun } })

# Assert
Assert-Equal -Expected @('', '1 passed, 2 failed') -Actual $lines -Message 'A failing tally prints itself'
Assert-Equal -Expected 2 -Actual $script:code -Message 'and the exit code is the failure count'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 0 -Failed 300 -ScriptBlock { Complete-TestRun } })

# Assert
Assert-Equal -Expected @('', '0 passed, 300 failed') -Actual $lines `
    -Message 'A tally past 255 still prints its true count'
Assert-Equal -Expected 255 -Actual $script:code -Message 'but the exit code is capped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$left = Invoke-WithTally -Passed 1 -Failed 2 -ScriptBlock {
    $null = Complete-TestRun 6>$null
    $tally = & (Get-Module TaffarelJr.TestKit) { Get-TestTally }
    "$($tally.Passed) passed, $($tally.Failed) failed"
}

# Assert
Assert-Equal -Expected '0 passed, 0 failed' -Actual $left `
    -Message 'Completing a run empties the tally for the next file in the session'

exit (Complete-TestRun)
