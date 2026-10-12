#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/ConvertTo-JsonLiteral.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Equal -Expected '"disable"' -Actual (ConvertTo-JsonLiteral -Value 'disable') -Message 'A string is quoted'
Assert-Equal -Expected '"say \"hi\" \\ done"' -Actual (ConvertTo-JsonLiteral -Value 'say "hi" \ done') `
    -Message 'Quotes and backslashes inside a string are escaped'
Assert-Equal -Expected '"a\nb"' -Actual (ConvertTo-JsonLiteral -Value "a`nb") `
    -Message 'A newline inside a string is escaped'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Equal -Expected 'true' -Actual (ConvertTo-JsonLiteral -Value $true) -Message 'A boolean is a bare literal'
Assert-Equal -Expected '5' -Actual (ConvertTo-JsonLiteral -Value 5) -Message 'A number is a bare literal'
Assert-Equal -Expected 'null' -Actual (ConvertTo-JsonLiteral -Value $null) -Message '$null is null'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Equal -Expected '[80,120]' -Actual (ConvertTo-JsonLiteral -Value @(80, 120)) `
    -Message 'An array is one line, with no spaces'
Assert-Equal -Expected '["only"]' -Actual (ConvertTo-JsonLiteral -Value @('only')) `
    -Message 'A one-element array stays an array'
Assert-Equal -Expected '[]' -Actual (ConvertTo-JsonLiteral -Value @()) -Message 'An empty array is []'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Equal -Expected '{"**/bin":true}' -Actual (ConvertTo-JsonLiteral -Value @{ '**/bin' = $true }) `
    -Message 'A dictionary is one line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - twelve levels of nesting, past ConvertTo-Json's own default
$deep = @{ l1 = @{ l2 = @{ l3 = @{ l4 = @{ l5 = @{ l6 = @{ l7 = @{ l8 = @{ l9 = @{ l10 = @{ l11 = @{ l12 = 1 } } } } } } } } } } } }

# Act
$literal = ConvertTo-JsonLiteral -Value $deep

# Assert
$expected = '{"l1":{"l2":{"l3":{"l4":{"l5":{"l6":{"l7":{"l8":{"l9":{"l10":{"l11":{"l12":1}}}}}}}}}}}}'
Assert-Equal -Expected $expected -Actual $literal `
    -Message 'A value nested twelve levels deep is written whole, not cut off as a type name'

exit (Complete-TestRun)
