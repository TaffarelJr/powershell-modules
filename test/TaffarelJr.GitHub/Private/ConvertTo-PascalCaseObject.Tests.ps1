#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub/Private/ConvertTo-PascalCaseObject.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a flat object as gh's --json output parses
$flat = '{"number":12,"headRefName":"feature","isDraft":false,"url":"https://x"}' | ConvertFrom-Json

# Act
$flatResult = ConvertTo-PascalCaseObject -InputObject $flat

# Assert
Assert-Equal -Expected @('Number', 'HeadRefName', 'IsDraft', 'Url') -Actual @($flatResult.PSObject.Properties.Name) -Message 'Every camelCase property name is re-cased to PascalCase, in order'
Assert-Equal -Expected 12 -Actual $flatResult.Number -Message 'A number value is carried over unchanged'
Assert-Equal -Expected 'feature' -Actual $flatResult.HeadRefName -Message 'A string value is carried over unchanged'
Assert-Equal -Expected $false -Actual $flatResult.IsDraft -Message 'A bool value is carried over unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nested objects and an array of objects
$nested = '{"author":{"login":"octocat"},"labels":[{"name":"bug"},{"name":"docs"}]}' | ConvertFrom-Json

# Act
$nestedResult = ConvertTo-PascalCaseObject -InputObject $nested

# Assert
Assert-Equal -Expected 'octocat' -Actual $nestedResult.Author.Login -Message 'A nested object is re-cased too'
Assert-Equal -Expected 2 -Actual $nestedResult.Labels.Count -Message 'An array of objects keeps every element'
Assert-Equal -Expected 'docs' -Actual $nestedResult.Labels[1].Name -Message 'Each element of an array is re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a top-level array, as a list command returns
$list = ConvertFrom-Json -InputObject '[{"tagName":"v1"}]' -NoEnumerate

# Act
$listResult = ConvertTo-PascalCaseObject -InputObject $list

# Assert
Assert-That -Condition ($listResult -is [array]) -Message 'A one-element array is still an array, not unrolled'
Assert-Equal -Expected 1 -Actual $listResult.Count -Message 'A one-element array keeps its one element'
Assert-Equal -Expected 'v1' -Actual $listResult[0].TagName -Message 'The element of a top-level array is re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Act - an empty array
$emptyResult = ConvertTo-PascalCaseObject -InputObject (ConvertFrom-Json -InputObject '[]' -NoEnumerate)

# Assert
Assert-That -Condition ($emptyResult -is [array]) -Message 'An empty array is still an array'
Assert-Equal -Expected 0 -Actual $emptyResult.Count -Message 'An empty array stays empty'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - scalars pass through untouched
Assert-Equal -Expected 'plain' -Actual (ConvertTo-PascalCaseObject -InputObject 'plain') -Message 'A string is returned as-is'
Assert-Equal -Expected 7 -Actual (ConvertTo-PascalCaseObject -InputObject 7) -Message 'A number is returned as-is'
Assert-That -Condition ($null -eq (ConvertTo-PascalCaseObject -InputObject $null)) -Message '$null is returned as $null'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a date value and a name that is already PascalCase
$typed = '{"createdAt":"2026-01-02T03:04:05Z","Already":"kept"}' | ConvertFrom-Json

# Act
$typedResult = ConvertTo-PascalCaseObject -InputObject $typed

# Assert
Assert-That -Condition ($typedResult.CreatedAt -is [datetime]) -Message 'A date ConvertFrom-Json already typed stays a [datetime]'
Assert-Equal -Expected 'kept' -Actual $typedResult.Already -Message 'A property already in PascalCase is left alone'

exit (Complete-TestRun)
