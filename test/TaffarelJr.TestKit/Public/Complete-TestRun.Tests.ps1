#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot '..' 'TestKitTestHelper.ps1')

# Complete-TestRun reads this process's running tally, so every case runs against
# a tally set for the purpose. The counts and exit codes are checked through
# Assert-ThatOrThrow: a kit that miscounted could otherwise report itself green.

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 0 -Failed 0 -ScriptBlock { Complete-TestRun } })

# Assert
Assert-Equal -Expected 3 -Actual $lines.Count -Message 'An empty tally prints itself, then says why that fails'
Assert-Equal -Expected '0 passed, 0 failed' -Actual $lines[1] -Message 'The tally line is the usual one'
Assert-That -Condition ($lines[2] -like 'No assertions ran.*Skip-TestRun*-AllowEmpty*') `
    -Message 'The explanation names both ways to say it is on purpose'
Assert-ThatOrThrow -Condition (1 -eq $script:code) -Message 'and the exit code is 1'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 0 -Failed 0 -ScriptBlock { Complete-TestRun -AllowEmpty } })

# Assert
Assert-Equal -Expected @('', 'allowed empty - checks run by other means', '0 passed, 0 failed') -Actual $lines `
    -Message '-AllowEmpty accepts a file that made no assertions, marking it so just before the tally line'
Assert-ThatOrThrow -Condition (0 -eq $script:code) -Message 'and exits 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 0 -Failed 2 -ScriptBlock { Complete-TestRun -AllowEmpty } })

# Assert
Assert-Equal -Expected @('', '0 passed, 2 failed') -Actual $lines -Message '-AllowEmpty with failures prints no marker'
Assert-ThatOrThrow -Condition (2 -eq $script:code) -Message 'and never excuses a failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 2 -Failed 0 -ScriptBlock { Complete-TestRun -AllowEmpty } })

# Assert
Assert-Equal -Expected @('', '2 passed, 0 failed') -Actual $lines `
    -Message '-AllowEmpty after assertions ran prints no marker'
Assert-ThatOrThrow -Condition (0 -eq $script:code) -Message 'and exits 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 2 -Failed 0 -ScriptBlock { Complete-TestRun } })

# Assert
Assert-Equal -Expected @('', '2 passed, 0 failed') -Actual $lines -Message 'A clean tally prints just itself'
Assert-ThatOrThrow -Condition (0 -eq $script:code) -Message 'and the exit code is 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 1 -Failed 2 -ScriptBlock { Complete-TestRun } })

# Assert
Assert-Equal -Expected @('', '1 passed, 2 failed') -Actual $lines -Message 'A failing tally prints itself'
Assert-ThatOrThrow -Condition (2 -eq $script:code) -Message 'and the exit code is the failure count'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { $script:code = Invoke-WithTally -Passed 0 -Failed 300 -ScriptBlock { Complete-TestRun } })

# Assert
Assert-Equal -Expected @('', '0 passed, 300 failed') -Actual $lines `
    -Message 'A tally past 255 still prints its true count'
Assert-ThatOrThrow -Condition (255 -eq $script:code) -Message 'but the exit code is capped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$left = Invoke-WithTally -Passed 1 -Failed 2 -ScriptBlock {
    $null = Complete-TestRun 6>$null
    $tally = & (Get-Module TaffarelJr.TestKit) { Get-TestTally }
    "$($tally.Passed) passed, $($tally.Failed) failed"
}

# Assert
Assert-ThatOrThrow -Condition ('0 passed, 0 failed' -ceq $left) `
    -Message 'Completing a run empties the tally for the next file in the session'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the one claim only a real process can show: the capped code is what the operating
# system sees. The file sets the tally through the module scope instead of making 300 assertions.
$sandbox = (New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) "complete-$([Guid]::NewGuid())")).FullName
try {
    $manyFile = Join-Path $sandbox 'Many.Tests.ps1'
    Set-Content -LiteralPath $manyFile -Value @(
        "Import-Module '$modulePath' -Force"
        '& (Get-Module TaffarelJr.TestKit) { (Get-TestTally).Failed = 300 }'
        'exit (Complete-TestRun)'
    )

    # Act
    $manyOutput = @(& pwsh -NoProfile -NonInteractive -File $manyFile)
    $manyExitCode = $LASTEXITCODE

    # Assert
    Assert-ThatOrThrow -Condition ($manyOutput -contains '0 passed, 300 failed') `
        -Message 'A file run as a process prints its true count'
    Assert-ThatOrThrow -Condition (255 -eq $manyExitCode) `
        -Message 'and the process exits 255, since a POSIX status would wrap 256 to success'
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
