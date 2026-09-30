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
# Arrange / Act - assertions made from other runspaces, which share the one tally
$verdict = Get-AssertionVerdict {
    1..3 | ForEach-Object -Parallel {
        Import-Module $using:modulePath
        Assert-That -Condition $true -Message 'in a runspace'
    }
}

# Assert
Assert-ThatOrThrow -Condition (3 -eq $verdict.Passed) `
    -Message 'Assertions made in other runspaces count into the one tally'
Assert-Equal -Expected 3 -Actual @($verdict.Lines | Where-Object { $_ -like '*ok - in a runspace*' }).Count `
    -Message 'and each printed its line'

exit (Complete-TestRun)
