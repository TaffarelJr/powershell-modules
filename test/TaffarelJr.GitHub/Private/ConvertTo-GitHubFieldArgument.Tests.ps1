#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub/Private/ConvertTo-GitHubFieldArgument.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act - no fields at all
$none = ConvertTo-GitHubFieldArgument -Flag '--field' -Fields $null

# Assert
Assert-That -Condition ($none -is [array]) -Message 'No fields still returns an array'
Assert-Equal -Expected 0 -Actual $none.Count -Message 'No fields returns no arguments'

#───────────────────────────────────────────────────────────────────────────────
# Act - two string fields, given out of order
$sorted = ConvertTo-GitHubFieldArgument -Flag '--raw-field' -Fields @{ title = 'T'; body = 'B' }

# Assert
Assert-Equal -Expected @('--raw-field', 'body=B', '--raw-field', 'title=T') -Actual $sorted -Message 'Fields are emitted in sorted key order, each behind its own flag'

#───────────────────────────────────────────────────────────────────────────────
# Act - the values gh's -F typing understands
$typed = ConvertTo-GitHubFieldArgument -Flag '--field' -Fields @{ force = $true; draft = $false; parent = $null; count = 5 }

# Assert
Assert-Equal -Expected @('--field', 'count=5', '--field', 'draft=false', '--field', 'force=true', '--field', 'parent=null') -Actual $typed -Message 'Bools are lower-cased, $null becomes null, and a number is written as-is'

#───────────────────────────────────────────────────────────────────────────────
# Act - an array value
$list = ConvertTo-GitHubFieldArgument -Flag '--field' -Fields @{ names = @('a', 'b') }

# Assert
Assert-Equal -Expected @('--field', 'names[]=a', '--field', 'names[]=b') -Actual $list -Message 'An array value becomes one key[]=value pair per element'

#───────────────────────────────────────────────────────────────────────────────
# Act - an empty array value
$emptyList = ConvertTo-GitHubFieldArgument -Flag '--field' -Fields @{ names = @() }

# Assert
Assert-Equal -Expected @('--field', 'names[]') -Actual $emptyList -Message 'An empty array value becomes a bare key[]'

exit (Complete-TestRun)
