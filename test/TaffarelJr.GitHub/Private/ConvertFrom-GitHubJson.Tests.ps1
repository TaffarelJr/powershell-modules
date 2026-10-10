#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub/Private/ConvertTo-PascalCaseObject.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub/Private/ConvertFrom-GitHubJson.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a pretty-printed object across several lines, as gh emits it
$objectLines = @('{', '  "name": "repo",', '  "isPrivate": true', '}')

# Act
$object = ConvertFrom-GitHubJson -Lines $objectLines

# Assert
Assert-Equal -Expected 'repo' -Actual $object.Name -Message 'A JSON object parses into one object'
Assert-Equal -Expected $true -Actual $object.IsPrivate -Message 'Property names are re-cased to PascalCase'

#───────────────────────────────────────────────────────────────────────────────
# Act - a one-element array
$single = ConvertFrom-GitHubJson -Lines @('[{"number": 7}]')

# Assert
Assert-That -Condition ($single -is [array]) -Message 'A one-element JSON array stays an array'
Assert-Equal -Expected 7 -Actual $single[0].Number -Message 'The one element is parsed and re-cased'

#───────────────────────────────────────────────────────────────────────────────
# Act - an empty array
$empty = ConvertFrom-GitHubJson -Lines @('[]')

# Assert
Assert-That -Condition ($empty -is [array]) -Message 'An empty JSON array is an array, not $null'
Assert-Equal -Expected 0 -Actual $empty.Count -Message 'An empty JSON array has no elements'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - no output at all
Assert-That -Condition ($null -eq (ConvertFrom-GitHubJson -Lines @())) -Message 'No output lines parse to $null'
Assert-That -Condition ($null -eq (ConvertFrom-GitHubJson -Lines @('', '  '))) -Message 'Blank output lines parse to $null'

#───────────────────────────────────────────────────────────────────────────────
# Act - a raw API response, names kept as GitHub sent them
$kept = ConvertFrom-GitHubJson -Lines @('{"default_branch":"main","html_url":"https://x"}') -KeepFieldNames

# Assert
Assert-Equal -Expected 'main' -Actual $kept.default_branch -Message '-KeepFieldNames leaves a snake_case name untouched'
Assert-Equal -Expected @('default_branch', 'html_url') -Actual @($kept.PSObject.Properties.Name) -Message '-KeepFieldNames re-cases nothing'

exit (Complete-TestRun)
