#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot '..' 'TestKitTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected 5 -Actual 5 -Message 'values match' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - values match' `
    -Message 'Equal values pass, printing the case message with nothing added'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected 'expected-value' -Actual 'actual-value' -Message 'values should match' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed `
    -LineLike '  FAIL - values should match (expected "expected-value", got "actual-value") `[Assert-Equal.Tests.ps1:*`]' `
    -Message 'Unequal values fail, naming the case and both values, quoted'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected 'Abc' -Actual 'abc' -Message 'case' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - case (expected "Abc", got "abc")*' `
    -Message 'Values differing only in case fail'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected '1' -Actual 1 -Message 'type' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - type (expected "1", got 1)*' `
    -Message 'A string and a number of the same text fail, showing which one was the string'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected $true -Actual $false -Message 'flag' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - flag (expected true, got false)*' `
    -Message 'Unequal booleans fail'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$when = [DateTime]::new(2026, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)

# Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected $when -Actual $when.AddMilliseconds(1) -Message 'when' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed `
    -LineLike '  FAIL - when (expected `[DateTime`] 2026-01-01T00:00:00.0000000Z, got `[DateTime`] 2026-01-01T00:00:00.0010000Z)*' `
    -Message 'Dates a millisecond apart fail, and print apart'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected ([DayOfWeek]::Monday) -Actual ([DayOfWeek]::Tuesday) -Message 'day' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed `
    -LineLike '  FAIL - day (expected `[DayOfWeek`] Monday, got `[DayOfWeek`] Tuesday)*' `
    -Message 'Unequal enum values fail'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected ([float]0.1) -Actual 0.1 -Message 'precision' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed `
    -LineLike '  FAIL - precision (expected `[Single`] 0.1, got `[Double`] 0.1)*' `
    -Message 'A float and a double of the same text fail, and print apart by their types'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - floats and doubles inside an array and a hashtable
$listVerdict = Get-AssertionVerdict { Assert-Equal -Expected @([float]0.1) -Actual @(0.1) -Message 'list' }
$tableVerdict = Get-AssertionVerdict { Assert-Equal -Expected @{ a = [float]0.1 } -Actual @{ a = 0.1 } -Message 'table' }

# Assert
Assert-Verdict -Verdict $listVerdict -Outcome Failed `
    -LineLike '  FAIL - list (expected `[0.1`], got `[0.1`] - the values print alike but differ)*' `
    -Message 'Lists that print alike but differ fail, saying so'
Assert-Verdict -Verdict $tableVerdict -Outcome Failed `
    -LineLike '  FAIL - table (expected `[Hashtable`] {"a":0.1}, got `[Hashtable`] {"a":0.1} - the values print alike but differ)*' `
    -Message 'and so do hashtables'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$nearVerdict = Get-AssertionVerdict { Assert-Equal -Expected ([decimal]1) -Actual (1 + 1e-15) -Message 'near' }
$nearestVerdict = Get-AssertionVerdict { Assert-Equal -Expected ([decimal]0.3) -Actual 0.3 -Message 'nearest' }

# Assert
Assert-Verdict -Verdict $nearVerdict -Outcome Failed `
    -LineLike '  FAIL - near (expected `[Decimal`] 1.0, got `[Double`] 1.000000000000001)*' `
    -Message 'A decimal does not equal a double that only rounds to it'
Assert-Verdict -Verdict $nearestVerdict -Outcome Passed -LineLike '  ok - nearest' `
    -Message 'but equals the double nearest to it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$bigListVerdict = Get-AssertionVerdict { Assert-Equal -Expected @([bigint]5) -Actual @([bigint]7) -Message 'big list' }

# Assert
Assert-Verdict -Verdict $bigListVerdict -Outcome Failed -LineLike '  FAIL - big list (expected `[5`], got `[7`])*' `
    -Message 'Big integers inside a list print as their values'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$bigAndIntVerdict = Get-AssertionVerdict { Assert-Equal -Expected @([bigint]5) -Actual @(5) -Message 'big and int' }

# Assert
Assert-Verdict -Verdict $bigAndIntVerdict -Outcome Failed `
    -LineLike '  FAIL - big and int (expected `[5`], got `[5`] - the values print alike but differ)*' `
    -Message 'and a list of a big integer and one of an int of the same value print alike, saying so'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected ([bigint]5) -Actual 5 -Message 'big' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - big (expected `[BigInteger`] 5, got 5)*' `
    -Message 'A big integer is not a number here, so it never equals an int of the same value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected @('a b') -Actual @('a', 'b') -Message 'shape' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - shape (expected `["a b"`], got `["a","b"`])*' `
    -Message 'One element holding a space and two elements print differently'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected $null -Actual '' -Message 'null' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - null (expected null, got "")*' `
    -Message '$null and an empty string print differently'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected @() -Actual @() -Message 'empty' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - empty' `
    -Message 'Two empty arrays are accepted and equal'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected @() -Actual $null -Message 'shape' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - shape (expected `[`], got null)*' `
    -Message 'An empty array and $null fail, rather than crash'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected @{ a = @(1, 2) } -Actual @{ a = @(1, 2) } -Message 'deep' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - deep' `
    -Message 'Hashtables with equal contents are equal'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected ([PSCustomObject]@{ a = 1 }) -Actual ([PSCustomObject]@{ a = 2 }) -Message 'deep' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed `
    -LineLike '  FAIL - deep (expected `[PSCustomObject`] {"a":1}, got `[PSCustomObject`] {"a":2})*' `
    -Message 'Objects with different contents fail, showing what differed inside them'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected @{ a = 1 } -Actual ([PSCustomObject]@{ a = 1 }) -Message 'kind' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed `
    -LineLike '  FAIL - kind (expected `[Hashtable`] {"a":1}, got `[PSCustomObject`] {"a":1})*' `
    -Message 'A hashtable and an object of the same content fail, and print apart'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$expected = 'x' * 300 + 'a'
$actual = 'x' * 300 + 'b'

# Act
$verdict = Get-AssertionVerdict { Assert-Equal -Expected $expected -Actual $actual -Message 'long' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - long (expected ...*xa", got ...*xb")*' `
    -Message 'Long strings differing near the end print the part where they differ'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a forgotten -Actual, run in a child process because a missing
# mandatory parameter would otherwise prompt
$command = "Import-Module '$modulePath' -Force; Assert-Equal -Expected `$null -Message 'no second value'"

# Act
$output = (@(& pwsh -NoProfile -NonInteractive -Command $command 2>&1) | Out-String)

# Assert
Assert-That -Condition ($output -like '*missing mandatory parameters: Actual*') `
    -Message 'A forgotten -Actual is a binding error naming it'
Assert-That -Condition ($output -notlike '*ok - *') -Message 'and nothing passes'

exit (Complete-TestRun)
