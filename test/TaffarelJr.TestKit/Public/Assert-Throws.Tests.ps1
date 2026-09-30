#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1'
Import-Module $modulePath -Force
. (Join-Path $PSScriptRoot '..' 'TestKitTestHelper.ps1')

$missingFile = Join-Path ([Path]::GetTempPath()) "no-such-file-$([Guid]::NewGuid()).txt"

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { throw 'boom' } -Message 'it throws' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - it throws' `
    -Message 'A script block that throws passes, printing the case message with nothing added'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { 'no exception here' } -Message 'it should throw' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - it should throw (did not throw)*' `
    -Message 'A script block that does not throw fails, and says so'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { throw 'could not run the tool' } -MessageLike '*could not run*' -Message 'message' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - message' `
    -Message 'A message matching -MessageLike passes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { throw 'something else' } -MessageLike '*could not run*' -Message 'message' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - message (message was: something else)*' `
    -Message 'A message not matching -MessageLike fails, showing the message that was thrown'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { throw 'names Source.txt and Target.txt' } -MessageLike '*Source.txt*', '*Target.txt*' -Message 'both' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - both' `
    -Message 'A message matching every pattern given passes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { throw 'names Source.txt only' } -MessageLike '*Source.txt*', '*Target.txt*' -Message 'both' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - both (message was: names Source.txt only)*' `
    -Message 'A message missing any one of the patterns fails'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { throw "no such folder '[x]'" } -MessageLike "*$([WildcardPattern]::Escape("'[x]'"))*" -Message 'literal' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - literal' `
    -Message 'A bracket in the message matches once the pattern is escaped'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a pattern list that would check nothing
Assert-Throws -ScriptBlock { Assert-Throws -ScriptBlock { throw 'x' } -MessageLike @() -Message 'm' } `
    -MessageLike "*parameter 'MessageLike'*" `
    -Message 'An empty -MessageLike is refused, not taken as no check'
Assert-Throws -ScriptBlock { Assert-Throws -ScriptBlock { throw 'x' } -MessageLike $null -Message 'm' } `
    -MessageLike "*parameter 'MessageLike'*" `
    -Message 'and so is a $null one'
Assert-Throws -ScriptBlock { Assert-Throws -ScriptBlock { throw 'x' } -MessageLike '' -Message 'm' } `
    -MessageLike "*parameter 'MessageLike'*" `
    -Message 'and an empty pattern'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a type that would check nothing
Assert-Throws -ScriptBlock { Assert-Throws -ScriptBlock { throw 'x' } -ExceptionType $null -Message 'm' } `
    -MessageLike "*parameter 'ExceptionType'*" `
    -Message 'A $null -ExceptionType is refused, not taken as no check'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { throw [ArgumentException]::new('bad') } -ExceptionType ([ArgumentException]) -Message 'type' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - type' `
    -Message 'An exception of the expected type passes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { throw [ArgumentNullException]::new('p') } -ExceptionType ([ArgumentException]) -Message 'type' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - type' `
    -Message 'An exception deriving from the expected type passes'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { Get-ACommandThatDoesNotExist } -ExceptionType ([ArgumentException]) -Message 'type' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed `
    -LineLike '  FAIL - type (threw CommandNotFoundException, expected ArgumentException: *' `
    -Message 'A different exception - here a typo in a command name - fails, naming what was thrown and what was expected'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { throw [ArgumentException]::new('wrong text') } -ExceptionType ([ArgumentException]) -MessageLike 'right*' -Message 'both' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Failed -LineLike '  FAIL - both (message was: wrong text)*' `
    -Message 'Both checks apply: the right type with the wrong message fails'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a .NET method's exception arrives wrapped in another
$verdict = Get-AssertionVerdict { Assert-Throws -ScriptBlock { [File]::ReadAllText($missingFile) } -ExceptionType ([FileNotFoundException]) -MessageLike "*$([WildcardPattern]::Escape($missingFile))*" -Message 'wrapped' }

# Assert
Assert-Verdict -Verdict $verdict -Outcome Passed -LineLike '  ok - wrapped' `
    -Message 'The type and message are looked for in the inner exceptions too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$wrapped = { throw [InvalidOperationException]::new('outer', [ArgumentException]::new('inner detail')) }

# Act
$byType = Get-AssertionVerdict { Assert-Throws -ScriptBlock $wrapped -ExceptionType ([ArgumentException]) -Message 'inner type' }
$byMessage = Get-AssertionVerdict { Assert-Throws -ScriptBlock $wrapped -MessageLike 'inner detail' -Message 'inner message' }
$wrongType = Get-AssertionVerdict { Assert-Throws -ScriptBlock $wrapped -ExceptionType ([FormatException]) -Message 'no type' }
$wrongMessage = Get-AssertionVerdict { Assert-Throws -ScriptBlock $wrapped -MessageLike 'elsewhere' -Message 'no message' }

# Assert
Assert-Verdict -Verdict $byType -Outcome Passed -LineLike '  ok - inner type' `
    -Message 'An inner exception of the expected type passes'
Assert-Verdict -Verdict $byMessage -Outcome Passed -LineLike '  ok - inner message' `
    -Message 'An inner exception with a matching message passes'
Assert-Verdict -Verdict $wrongType -Outcome Failed `
    -LineLike '  FAIL - no type (threw InvalidOperationException > ArgumentException, expected FormatException: outer)*' `
    -Message 'With no link of the type, the failure names every link'
Assert-Verdict -Verdict $wrongMessage -Outcome Failed `
    -LineLike '  FAIL - no message (message was: outer; inner: inner detail)*' `
    -Message 'With no link matching, the failure shows every message'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - under Turkish casing rules, where the capital I lowercases to a dotless ı
$cultureBefore = [cultureinfo]::CurrentCulture

# Act
try {
    [cultureinfo]::CurrentCulture = [cultureinfo]'tr-TR'
    $turkish = Get-AssertionVerdict {
        Assert-Throws -ScriptBlock { throw 'INFO: the tool said so' } -MessageLike 'info*' -Message 'turkish'
    }
}
finally {
    [cultureinfo]::CurrentCulture = $cultureBefore
}

# Assert
Assert-Verdict -Verdict $turkish -Outcome Passed -LineLike '  ok - turkish' `
    -Message 'A message pattern ignores case the same way whatever the culture is'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$lines = @(Get-HostOutput { Assert-Throws -ScriptBlock { 'a value, not output' ; throw 'boom' } -Message 'quiet' })

# Assert
Assert-Equal -Expected @('  ok - quiet') -Actual $lines `
    -Message 'A value the block produced before throwing does not leak out as output'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an AggregateException holding two inner exceptions
$inner = [Exception[]]@([FileNotFoundException]::new('first inner'), [ArgumentException]::new('second inner'))
$aggregate = { throw [AggregateException]::new('two failures', $inner) }

# Act
$firstInner = Get-AssertionVerdict { Assert-Throws -ScriptBlock $aggregate -ExceptionType ([FileNotFoundException]) -Message 'first' }
$secondInner = Get-AssertionVerdict { Assert-Throws -ScriptBlock $aggregate -ExceptionType ([ArgumentException]) -Message 'second' }
$secondMessage = Get-AssertionVerdict { Assert-Throws -ScriptBlock $aggregate -MessageLike 'second inner' -Message 'second text' }

# Assert
Assert-Verdict -Verdict $firstInner -Outcome Passed -LineLike '  ok - first' `
    -Message 'The first of an AggregateException''s inner exceptions is found by type'
Assert-Verdict -Verdict $secondInner -Outcome Passed -LineLike '  ok - second' `
    -Message 'and so is the second, which InnerException alone would never reach'
Assert-Verdict -Verdict $secondMessage -Outcome Passed -LineLike '  ok - second text' `
    -Message 'and its message is matched too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a block that writes a non-terminating error, under a caller whose preference is Continue
function Get-NonTerminatingVerdict {
    $ErrorActionPreference = 'Continue'
    $verdict = Get-AssertionVerdict {
        Assert-Throws -ScriptBlock { Write-Error 'wrote, did not throw' } `
            -MessageLike 'wrote, did not throw' -Message 'written'
    }
    Write-Output -InputObject $verdict
    Write-Output -InputObject "$ErrorActionPreference"
}

# Act
$written = @(Get-NonTerminatingVerdict)

# Assert
Assert-Verdict -Verdict $written[0] -Outcome Passed -LineLike '  ok - written' `
    -Message 'A non-terminating error in the block counts as a throw whatever the caller''s preference is'
Assert-Equal -Expected 'Continue' -Actual $written[1] -Message 'and the caller''s preference is put back'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an ErrorRecord caught earlier and thrown again
$record = $null
try {
    Get-Item -LiteralPath $missingFile -ErrorAction Stop
}
catch {
    $record = $_
}

# Act
$rethrown = Get-AssertionVerdict { Assert-Throws -ScriptBlock { throw $record } -ExceptionType ([Management.Automation.ItemNotFoundException]) -Message 'record' }

# Assert
Assert-Verdict -Verdict $rethrown -Outcome Passed -LineLike '  ok - record' `
    -Message 'A rethrown ErrorRecord is matched by the type of the exception it carries'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a pattern that is not a valid wildcard
Assert-Throws -ScriptBlock { Assert-Throws -ScriptBlock { throw 'x' } -MessageLike 'no closing [bracket' -Message 'm' } `
    -ExceptionType ([Management.Automation.WildcardPatternException]) `
    -Message 'An invalid wildcard in -MessageLike is an error of the call, not a counted failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an AggregateException holding two inner exceptions
$inner = [Exception[]]@([FileNotFoundException]::new('first inner'), [ArgumentException]::new('second inner'))
$aggregate = { throw [AggregateException]::new('two failures', $inner) }

# Act
$firstInner = Get-AssertionVerdict { Assert-Throws -ScriptBlock $aggregate -ExceptionType ([FileNotFoundException]) -Message 'first' }
$secondInner = Get-AssertionVerdict { Assert-Throws -ScriptBlock $aggregate -ExceptionType ([ArgumentException]) -Message 'second' }
$secondMessage = Get-AssertionVerdict { Assert-Throws -ScriptBlock $aggregate -MessageLike 'second inner' -Message 'second text' }

# Assert
Assert-Verdict -Verdict $firstInner -Outcome Passed -LineLike '  ok - first' `
    -Message 'The first of an AggregateException''s inner exceptions is found by type'
Assert-Verdict -Verdict $secondInner -Outcome Passed -LineLike '  ok - second' `
    -Message 'and so is the second, which InnerException alone would never reach'
Assert-Verdict -Verdict $secondMessage -Outcome Passed -LineLike '  ok - second text' `
    -Message 'and its message is matched too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a block that writes a non-terminating error, under a caller whose preference is Continue
function Get-NonTerminatingVerdict {
    $ErrorActionPreference = 'Continue'
    $verdict = Get-AssertionVerdict {
        Assert-Throws -ScriptBlock { Write-Error 'wrote, did not throw' } `
            -MessageLike 'wrote, did not throw' -Message 'written'
    }
    Write-Output -InputObject $verdict
    Write-Output -InputObject "$ErrorActionPreference"
}

# Act
$written = @(Get-NonTerminatingVerdict)

# Assert
Assert-Verdict -Verdict $written[0] -Outcome Passed -LineLike '  ok - written' `
    -Message 'A non-terminating error in the block counts as a throw whatever the caller''s preference is'
Assert-Equal -Expected 'Continue' -Actual $written[1] -Message 'and the caller''s preference is put back'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an ErrorRecord caught earlier and thrown again
$record = $null
try {
    Get-Item -LiteralPath $missingFile -ErrorAction Stop
}
catch {
    $record = $_
}

# Act
$rethrown = Get-AssertionVerdict { Assert-Throws -ScriptBlock { throw $record } -ExceptionType ([Management.Automation.ItemNotFoundException]) -Message 'record' }

# Assert
Assert-Verdict -Verdict $rethrown -Outcome Passed -LineLike '  ok - record' `
    -Message 'A rethrown ErrorRecord is matched by the type of the exception it carries'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a pattern that is not a valid wildcard
Assert-Throws -ScriptBlock { Assert-Throws -ScriptBlock { throw 'x' } -MessageLike 'no closing [bracket' -Message 'm' } `
    -ExceptionType ([Management.Automation.WildcardPatternException]) `
    -Message 'An invalid wildcard in -MessageLike is an error of the call, not a counted failure'

exit (Complete-TestRun)
