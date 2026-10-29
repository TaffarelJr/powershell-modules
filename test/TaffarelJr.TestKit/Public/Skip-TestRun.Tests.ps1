#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot '..' 'TestKitTestHelper.ps1')

# Skip-TestRun reads this process's running tally, so the first cases run in a
# fresh child process.

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a file skipped before any assertion
$skipScript = "Import-Module '$modulePath' -Force; exit (Skip-TestRun -Reason 'gh has no login here')"

# Act
$skipOutput = @(& pwsh -NoProfile -NonInteractive -Command $skipScript)
$skipExitCode = $LASTEXITCODE

# Assert
Assert-Equal -Expected 'skipped - gh has no login here' -Actual $skipOutput[0] `
    -Message 'The first line says it was skipped, and why'
Assert-That -Condition ($skipOutput -contains '0 passed, 0 failed') `
    -Message 'It still prints the tally line a runner reads'
Assert-Equal -Expected 0 -Actual $skipExitCode -Message 'A skipped file exits 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a skip after the file has already asserted something
$lateScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-That -Condition `$true -Message 'a'; " `
    + "try { Skip-TestRun -Reason 'too late' } catch { `$_.Exception.Message }"

# Act
$lateOutput = @(& pwsh -NoProfile -NonInteractive -Command $lateScript)

# Assert
Assert-That -Condition ($lateOutput[-1] -like '*after assertions ran*') `
    -Message 'Skipping after assertions have run is an error that says so'

$sandbox = (New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) "skip-$([Guid]::NewGuid())")).FullName
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a skipped file run after a passing one in the same session
    $passFile = Join-Path $sandbox 'Pass.Tests.ps1'
    $skipFile = Join-Path $sandbox 'Skip.Tests.ps1'
    Set-Content -LiteralPath $passFile `
        -Value "Import-Module '$modulePath' -Force; Assert-That -Condition `$true -Message 'p'; exit (Complete-TestRun)"
    Set-Content -LiteralPath $skipFile `
        -Value "Import-Module '$modulePath' -Force; exit (Skip-TestRun -Reason 'not here')"
    $passThenSkip = "& '$passFile'; `$first = `$LASTEXITCODE; & '$skipFile'; 'exit codes ' + `$first + ' ' + `$LASTEXITCODE"

    # Act
    $passThenSkipOutput = @(& pwsh -NoProfile -NonInteractive -Command $passThenSkip 2>&1)

    # Assert
    Assert-That -Condition ($passThenSkipOutput -contains 'skipped - not here') `
        -Message 'A skipped file after a passing one in the same session is skipped'
    Assert-Equal -Expected 'exit codes 0 0' -Actual "$($passThenSkipOutput[-1])" `
        -Message 'and exits 0, rather than throwing over the earlier file''s assertions'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

# The same cases again in this process, against a tally set for the purpose,
# so coverage can see them.

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
