#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force

# Arrange / Act / Assert - a value with no rules passes through unchanged
Assert-Equal -Expected 'abc' -Actual ('abc' | Assert-Input) -Message 'A value with no rules passes through unchanged'

# Arrange / Act - an empty value without -Require passes through untouched,
# skipping every other check (an impossible pattern would otherwise reject it)
$result = Assert-Input -Value '' -Pattern '^\d+$'

# Assert
Assert-Equal -Expected '' -Actual $result -Message 'An empty value skips -Pattern and every other check when not -Require'

# Arrange / Act / Assert - -Require rejects an empty value, naming the label
try {
    Assert-Input -Value '' -Require -Label 'Repo name'
    Assert-That -Condition $false -Message '-Require throws on an empty value (did not throw)'
}
catch {
    Assert-Equal -Expected 'Repo name is required' -Actual $_.Exception.Message -Message '-Require names the label in the thrown message'
}

# Arrange / Act / Assert - -Require without a label still throws a sensible message
try {
    Assert-Input -Value '' -Require
    Assert-That -Condition $false -Message '-Require without -Label still throws (did not throw)'
}
catch {
    Assert-Equal -Expected 'is required' -Actual $_.Exception.Message -Message 'The message has no leading label when none is given'
}

# Arrange / Act / Assert - -Choice rejects a value outside the list
try {
    Assert-Input -Value 'Archived' -Choice 'Public', 'Private'
    Assert-That -Condition $false -Message '-Choice rejects an unlisted value (did not throw)'
}
catch {
    Assert-Equal -Expected 'must be one of: Public, Private' -Actual $_.Exception.Message -Message '-Choice names the allowed values'
}

# Arrange / Act - -Choice re-cases a case-insensitive match
$result = Assert-Input -Value 'private' -Choice 'Public', 'Private'

# Assert
Assert-Equal -Expected 'Private' -Actual $result -Message '-Choice returns the casing the choice list declares'

# Arrange / Act / Assert - -Pattern rejects, using -Requirement's wording
try {
    Assert-Input -Value 'abc' -Pattern '^\d+$' -Requirement 'must be all digits'
    Assert-That -Condition $false -Message '-Pattern rejects a non-matching value (did not throw)'
}
catch {
    Assert-Equal -Expected 'must be all digits' -Actual $_.Exception.Message -Message '-Requirement supplies the thrown wording'
}

# Arrange / Act / Assert - -Pattern without -Requirement
#falls back to a generic message
try {
    Assert-Input -Value 'abc' -Pattern '^\d+$'
    Assert-That -Condition $false -Message '-Pattern rejects without -Requirement (did not throw)'
}
catch {
    Assert-Equal -Expected 'must match ^\d+$' -Actual $_.Exception.Message -Message 'The fallback message names the raw pattern'
}

# Arrange / Act / Assert - -Requirement without -Pattern is rejected immediately
try {
    Assert-Input -Value 'anything' -Requirement 'must be all digits'
    Assert-That -Condition $false -Message '-Requirement without -Pattern throws (did not throw)'
}
catch {
    Assert-Equal -Expected '-Requirement has no effect without -Pattern' -Actual $_.Exception.Message -Message 'The mismatch is reported before any value is even checked'
}

# Arrange / Act / Assert - -Validate rejects, using the reason it returns
try {
    Assert-Input -Value 'bad' -Validate { param($v) if ($v -eq 'bad') { 'is not allowed' } }
    Assert-That -Condition $false -Message '-Validate rejects via its own reason (did not throw)'
}
catch {
    Assert-Equal -Expected 'is not allowed' -Actual $_.Exception.Message -Message '-Validate supplies the thrown reason'
}

# Arrange / Act - -Validate accepts a value its scriptblock does not reject
$result = Assert-Input -Value 'good' -Validate { param($v) if ($v -eq 'bad') { 'is not allowed' } }

# Assert
Assert-Equal -Expected 'good' -Actual $result -Message '-Validate passes the value through when the scriptblock returns nothing'

# Arrange / Act - multiple pipeline items are each checked independently
$results = @('1', '22', '333') | Assert-Input -Pattern '^\d+$'

# Assert
Assert-Equal -Expected 3 -Actual $results.Count -Message 'Each pipeline item is checked and passed through independently'
Assert-Equal -Expected '22' -Actual $results[1] -Message 'The second item is returned unchanged'

exit (Complete-TestRun)
