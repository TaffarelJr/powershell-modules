#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$text = & $module { Format-FieldValue -Value "one`r`ntwo" }
$number = & $module { Format-FieldValue -Value 7 }
$nothing = & $module { Format-FieldValue -Value $null }

# Assert
Assert-Equal -Expected "one`r`ntwo" -Actual $text -Message 'Text is returned with its line breaks, for the writer to split'
Assert-Equal -Expected '7' -Actual $number -Message 'A value that is not text gives the text it prints as'
Assert-Equal -Expected '' -Actual $nothing -Message 'and $null gives empty text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$list = & $module { Format-FieldValue -Value @('a', @('b', 'c'), 'd') }
$empty = & $module { Format-FieldValue -Value @() }

# Assert
Assert-Equal -Expected "a`nb`nc`nd" -Actual $list -Message 'A list gives one line per item, a list inside it flattened'
Assert-Equal -Expected '' -Actual $empty -Message 'An empty list gives empty text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$dictionary = & $module { Format-FieldValue -Value ([ordered]@{ b = @(1, 2); 2 = 'two'; a = @{ k = 'v' } }) }
$none = & $module { Format-FieldValue -Value @{} }

# Assert
Assert-Equal -Expected "2 = two`na = {k = v}`nb = 1, 2" -Actual $dictionary `
    -Message 'A dictionary gives one entry per line, sorted by the key''s text, a list and a dictionary inline'
Assert-Equal -Expected '' -Actual $none -Message 'An empty dictionary gives empty text'

exit (Complete-TestRun)
