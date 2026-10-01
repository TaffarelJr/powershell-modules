#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidAssignmentToAutomaticVariable',
    '',
    Justification = 'The test assigns the variable the code under test reads.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'UserInputTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a value with no rules passes through unchanged
Assert-Equal -Expected 'abc' -Actual ('abc' | Assert-Input) -Message 'A value with no rules passes through unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - an empty value without -Require passes through untouched,
# skipping every other check (an impossible pattern would otherwise reject it)
$result = Assert-Input -Value '' -Pattern '^\d+$'

# Assert
Assert-Equal -Expected '' -Actual $result `
    -Message 'An empty value skips -Pattern and every other check when not -Require'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Require rejects an empty value, naming the label
Assert-Throws -ScriptBlock {
    Assert-Input -Value '' -Require -Label 'Repo name'
} -Message '-Require throws on an empty value, naming the label' -MessageLike 'Repo name is required'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Require without a label still throws a sensible message
Assert-Throws -ScriptBlock {
    Assert-Input -Value '' -Require
} -Message '-Require without -Label still throws, with no leading label' -MessageLike 'is required'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Choice rejects a value outside the list
Assert-Throws -ScriptBlock {
    Assert-Input -Value 'Archived' -Choice 'Public', 'Private'
} -Message '-Choice rejects an unlisted value, naming the allowed values' -MessageLike 'must be one of: Public, Private'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Choice re-cases a case-insensitive match
$result = Assert-Input -Value 'private' -Choice 'Public', 'Private'

# Assert
Assert-Equal -Expected 'Private' -Actual $result -Message '-Choice returns the casing the choice list declares'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Pattern rejects, using -Requirement's wording
Assert-Throws -ScriptBlock {
    Assert-Input -Value 'abc' -Pattern '^\d+$' -Requirement 'must be all digits'
} -Message '-Pattern rejects a value, -Requirement supplies the wording' -MessageLike 'must be all digits'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Pattern without -Requirement
# falls back to a generic message
Assert-Throws -ScriptBlock {
    Assert-Input -Value 'abc' -Pattern '^\d+$'
} -Message 'The fallback message names the raw pattern' -MessageLike 'must match ^\d+$'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Requirement without -Pattern is rejected immediately
Assert-Throws -ScriptBlock {
    Assert-Input -Value 'anything' -Requirement 'must be all digits'
} -Message '-Requirement alone throws before any value check' -MessageLike '-Requirement has no effect without -Pattern'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Validate rejects, using the reason it returns
Assert-Throws -ScriptBlock {
    Assert-Input -Value 'bad' -Validate { param($v) if ($v -eq 'bad') { 'is not allowed' } }
} -Message '-Validate rejects, supplying the thrown reason' -MessageLike 'is not allowed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Validate accepts a value its scriptblock does not reject
$result = Assert-Input -Value 'good' -Validate { param($v) if ($v -eq 'bad') { 'is not allowed' } }

# Assert
Assert-Equal -Expected 'good' -Actual $result `
    -Message '-Validate passes the value through when the scriptblock returns nothing'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a predicate, as ValidateScript takes, instead of a reason
$isFolder = { param($v) $v -eq 'folder' }

# Act
$fromTrue = Get-ThrownError { Assert-Input -Value 'folder' -Validate $isFolder -Label 'Folder' }
$fromFalse = Get-ThrownError { Assert-Input -Value 'file' -Validate $isFolder -Label 'Folder' }

# Assert
Assert-Equal -Expected '-Validate must return a reason string or nothing, not a boolean' `
    -Actual $fromTrue.Exception.Message `
    -Message 'A -Validate that returns $true is refused rather than read as a reason'
Assert-Equal -Expected 'ValidateReturnedBoolean,Assert-Input' -Actual $fromTrue.FullyQualifiedErrorId `
    -Message 'as a mistake in the call, which Invoke-InputRetry does not retry'
Assert-Equal -Expected 'InvalidArgument' -Actual "$($fromTrue.CategoryInfo.Category)" `
    -Message 'in the InvalidArgument category'
Assert-Equal -Expected 'ValidateReturnedBoolean,Assert-Input' -Actual $fromFalse.FullyQualifiedErrorId `
    -Message 'and one that returns $false is refused too, rather than letting the value through'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - blocks that return something that is neither a reason nor nothing
$fromNumber = Get-ThrownError { Assert-Input -Value 'x' -Validate { 0 } -Label 'Port' }
$fromObject = Get-ThrownError { Assert-Input -Value 'x' -Validate { [PSCustomObject]@{ Reason = 'no' } } }
$mixed = Get-ThrownError { Assert-Input -Value 'x' -Validate { 'a reason'; 3 } }

# Assert
Assert-Equal -Expected '-Validate must return a reason string or nothing, not a [Int32]' `
    -Actual $fromNumber.Exception.Message `
    -Message 'A -Validate that returns a number is refused rather than let through'
Assert-Equal -Expected 'ValidateReturnedNonString,Assert-Input' -Actual $fromNumber.FullyQualifiedErrorId `
    -Message 'as a mistake in the call, which Invoke-InputRetry does not retry'
Assert-Equal -Expected 'InvalidArgument' -Actual "$($fromNumber.CategoryInfo.Category)" `
    -Message 'in the InvalidArgument category'
Assert-Equal -Expected '-Validate must return a reason string or nothing, not a [PSCustomObject]' `
    -Actual $fromObject.Exception.Message -Message 'and so is an object, which names its type'
Assert-Equal -Expected 'ValidateReturnedNonString,Assert-Input' -Actual $mixed.FullyQualifiedErrorId `
    -Message 'and one thing that is not text among the rest'

#───────────────────────────────────────────────────────────────────────────────
# Act - blocks that return nothing worth a reason
$fromEmpty = Assert-Input -Value 'x' -Validate { '' }
$fromNull = Assert-Input -Value 'x' -Validate { $null }

# Assert
Assert-Equal -Expected 'x' -Actual $fromEmpty -Message 'An empty string is no reason, so the value passes'
Assert-Equal -Expected 'x' -Actual $fromNull -Message 'and so is $null'

#───────────────────────────────────────────────────────────────────────────────
# Act - a choice list that differs only by case
$pair = Get-ThrownError { Assert-Input -Value 'yes' -Choice 'Yes', 'yes' -Label 'The answer' }
$piped = Get-ThrownError { 'yes' | Assert-Input -Choice 'a', 'B', 'b' }

# Assert
Assert-Equal -Expected "-Choice lists 'yes' more than once, ignoring case, so a value could not be matched to one" `
    -Actual $pair.Exception.Message `
    -Message 'A -Choice list that holds one option twice, ignoring case, is refused, naming it'
Assert-Equal -Expected 'ChoiceDuplicated,Assert-Input' -Actual $pair.FullyQualifiedErrorId `
    -Message 'as a mistake in the call, which Invoke-InputRetry does not retry'
Assert-Equal -Expected 'InvalidArgument' -Actual "$($pair.CategoryInfo.Category)" `
    -Message 'in the InvalidArgument category'
Assert-Equal -Expected 'ChoiceDuplicated,Assert-Input' -Actual $piped.FullyQualifiedErrorId `
    -Message 'and the same when values are piped in, before the first one is looked at'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the caller's own $_ holds something else
$_ = 'stale'

# Act
$fromDollarUnder = 'abc' | Assert-Input -Validate { if ($_ -ne 'abc') { "saw [$_]" } }

# Assert
Assert-Equal -Expected 'abc' -Actual $fromDollarUnder -Message 'In -Validate, $_ is the value, as in ValidateScript'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a -Validate that throws
Assert-Throws -ScriptBlock {
    Assert-Input -Value 'x' -Validate { throw 'the rule broke' }
} -MessageLike 'the rule broke' -Message 'An error thrown inside -Validate comes out as it was thrown, not wrapped'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$script:validated = $null

# Act
$recased = Assert-Input -Value 'public' -Choice 'Public' -Pattern '^[A-Z]' `
    -Validate { param($v) $script:validated = $v }

# Assert
Assert-Equal -Expected 'Public' -Actual $recased `
    -Message 'A -Choice match is re-cased before -Pattern sees it, so a pattern about the declared casing passes'
Assert-Equal -Expected 'Public' -Actual $script:validated -Message 'and -Validate sees the re-cased value too'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - multiple pipeline items are each checked independently
$results = @('1', '22', '333') | Assert-Input -Pattern '^\d+$'

# Assert
Assert-Equal -Expected 3 -Actual $results.Count `
    -Message 'Each pipeline item is checked and passed through independently'
Assert-Equal -Expected '22' -Actual $results[1] -Message 'The second item is returned unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Pattern is case-sensitive: a rule about case means it
Assert-Throws -ScriptBlock {
    Assert-Input -Value 'ABC' -Pattern '^[a-z]+$'
} -MessageLike 'must match ^`[a-z`]+$' `
    -Message '-Pattern ^[a-z]+$ rejects ABC, so a lower-case-only rule can be written'
Assert-Equal -Expected 'abc' -Actual (Assert-Input -Value 'abc' -Pattern '^[a-z]+$') -Message 'and accepts abc'
Assert-Equal -Expected 'ABC' -Actual (Assert-Input -Value 'ABC' -Pattern '(?i)^[a-z]+$') `
    -Message 'A pattern that starts with (?i) ignores case'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - -Pattern is not anchored, so a partial match is a match
Assert-Equal -Expected 'abc123!!' -Actual (Assert-Input -Value 'abc123!!' -Pattern '[a-z]+') `
    -Message 'A pattern with no anchors matches anywhere in the value'
Assert-Throws -ScriptBlock {
    Assert-Input -Value 'abc123!!' -Pattern '^[a-z]+$'
} -MessageLike 'must match ^`[a-z`]+$' -Message 'and ^ and $ make it the whole value'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a pattern that is not a regular expression
$badPattern = Get-ThrownError { Assert-Input -Value 'x' -Pattern '[unclosed' }
$badPatternEmpty = Get-ThrownError { Assert-Input -Value '' -Pattern '[unclosed' }

# Assert
Assert-That `
    -Condition ($badPattern.Exception.Message -like '-Pattern is not a valid regular expression: *Unterminated*') `
    -Message 'An invalid -Pattern is reported as exactly that, with the reason'
Assert-Equal -Expected 'InvalidArgument' -Actual "$($badPattern.CategoryInfo.Category)" `
    -Message 'as a mistake in the call, not in the answer'
Assert-That -Condition ($null -ne $badPatternEmpty) `
    -Message 'and it is found even when the value is empty, so it cannot hide until a real answer arrives'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the other mistake in the call
$requirementOnly = Get-ThrownError { Assert-Input -Value 'x' -Requirement 'must be digits' }

# Assert
Assert-Equal -Expected 'InvalidArgument' -Actual "$($requirementOnly.CategoryInfo.Category)" `
    -Message '-Requirement with no -Pattern is also a mistake in the call'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - what a rejected answer is, as opposed to a mistake in the call
$rejected = Get-ThrownError { Assert-Input -Value 'abc' -Pattern '^\d+$' }

# Assert
Assert-That -Condition ("$($rejected.CategoryInfo.Category)" -ne 'InvalidArgument') `
    -Message 'A rejected answer is not an InvalidArgument error, so it can be asked again'

exit (Complete-TestRun)
