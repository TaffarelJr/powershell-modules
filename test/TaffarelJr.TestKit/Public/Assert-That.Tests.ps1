#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot '..' 'TestKitTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-That -Condition $true -Message 'something worked' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - something worked' `
    -Message 'A true condition prints one "ok" line with the message'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-That -Condition $false -Message 'something broke' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - something broke `[Assert-That.Tests.ps1:*`]' `
    -Message 'A false condition prints a "FAIL" line with the message and where in the test file it was made'
Assert-That -Condition ($verdict.Lines[0] -match '\[Assert-That\.Tests\.ps1:\d+\]$') `
    -Message 'The location is a line number'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - values that are not a boolean, which a bool parameter would turn into one
$notBooleans = @(
    @{ Name = 'a non-zero number'; Value = 3 }
    @{ Name = 'zero'; Value = 0 }
    @{ Name = 'a string'; Value = 'yes' }
    @{ Name = 'the string false'; Value = 'false' }
    @{ Name = 'an empty string'; Value = '' }
    @{ Name = 'an array holding $true'; Value = @($true) }
    @{ Name = 'an object'; Value = [PSCustomObject]@{ Ok = $true } }
)

foreach ($case in $notBooleans) {
    # Act / Assert
    Assert-Throws -ScriptBlock { Assert-That -Condition $case.Value -Message 'never counted' } `
        -ExceptionType ([ArgumentException]) `
        -MessageLike '*-Condition must be $true or $false*', "*(Parameter 'Condition')*" `
        -Message "$($case.Name) is refused as a condition, not read as true or false"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict {
    Assert-Throws -ScriptBlock { Assert-That -Condition 3 -Message 'a count' } -Message 'refused'
}

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - refused' `
    -Message 'A refused condition counts as nothing: the only case counted is the one around it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - booleans that arrive wrapped, as a cmdlet's output does
$wrapped = Test-Path -LiteralPath $PSScriptRoot
$missing = Test-Path -LiteralPath (Join-Path $PSScriptRoot 'no-such-file')

# Act
$passes = Get-AssertionVerdict { Assert-That -Condition $wrapped -Message 'a wrapped true' }
$fails = Get-AssertionVerdict { Assert-That -Condition $missing -Message 'a wrapped false' }

# Assert
Assert-Verdict -Verdict $passes -Outcome Passed -LineLike '  ok - a wrapped true' `
    -Message 'A boolean a cmdlet returned is still a boolean: true passes'
Assert-Verdict -Verdict $fails -Outcome Failed -LineLike '  FAIL - a wrapped false*' `
    -Message 'and false fails'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a false condition counts as a failure, in a child process
# because it would otherwise fail this file's own tally
$innerScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-That -Condition `$false -Message 'something broke'; " `
    + "exit (Complete-TestRun)"

# Act
$innerOutput = @(& pwsh -NoProfile -NonInteractive -Command $innerScript)
$innerExitCode = $LASTEXITCODE

# Assert
Assert-ThatOrThrow -Condition ($innerOutput -contains '0 passed, 1 failed') `
    -Message 'A single false condition tallies as 0 passed, 1 failed'
Assert-ThatOrThrow -Condition (1 -eq $innerExitCode) -Message 'The process exits with the failure count'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a mix of passes and failures
$mixedScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-That -Condition `$true -Message 'inner pass one'; " `
    + "Assert-That -Condition `$true -Message 'inner pass two'; " `
    + "Assert-That -Condition `$false -Message 'inner fail'; " `
    + "exit (Complete-TestRun)"

# Act
$mixedOutput = @(& pwsh -NoProfile -NonInteractive -Command $mixedScript)
$mixedExitCode = $LASTEXITCODE

# Assert
Assert-ThatOrThrow -Condition ($mixedOutput -contains '2 passed, 1 failed') `
    -Message 'Two passes and one failure tally correctly'
Assert-ThatOrThrow -Condition (1 -eq $mixedExitCode) -Message 'The process exits with the failure count'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - assertions made from several runspaces, as well as the main one
$parallelScript = "Import-Module '$modulePath' -Force; " `
    + "Assert-That -Condition `$true -Message 'main'; " `
    + "1..3 | ForEach-Object -Parallel { Import-Module '$modulePath'; Assert-That -Condition `$false -Message 'in a runspace' } | Out-Null; " `
    + "exit (Complete-TestRun)"

# Act
$parallelOutput = @(& pwsh -NoProfile -NonInteractive -Command $parallelScript)
$parallelExitCode = $LASTEXITCODE

# Assert
Assert-ThatOrThrow -Condition ($parallelOutput -contains '1 passed, 3 failed') `
    -Message 'Assertions made in other runspaces are counted too'
Assert-ThatOrThrow -Condition (3 -eq $parallelExitCode) -Message 'And they fail the file'

exit (Complete-TestRun)
