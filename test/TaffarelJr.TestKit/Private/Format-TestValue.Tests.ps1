#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Get-Module TaffarelJr.TestKit

#───────────────────────────────────────────────────────────────────────────────
# Act
$short = & $module { Format-TestValue -Value @{ a = 1 } }
$alongside = & $module { Format-TestValue -Value 'a' -Other 'b' }

# Assert
Assert-Equal -Expected '[Hashtable] {"a":1}' -Actual $short -Message 'A short rendering is the whole of it'
Assert-Equal -Expected '"a"' -Actual $alongside `
    -Message 'and stays whole when there is another value to compare it with'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a rendering far longer than a message should carry
$long = 'x' * 1000

# Act
$text = & $module { param($Value) Format-TestValue -Value $Value } $long

# Assert
Assert-Equal -Expected ('"' + 'x' * 239 + '...') -Actual $text `
    -Message 'A long rendering is cut to 240 characters, and the cut is marked'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - long values that differ early on
$value = 'a' + 'x' * 999
$other = 'b' + 'x' * 999

# Act
$text = & $module { param($Value, $Other) Format-TestValue -Value $Value -Other $Other } $value $other

# Assert
Assert-Equal -Expected ('"a' + 'x' * 238 + '...') -Actual $text `
    -Message 'A difference within the first part shows the first part'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - long values that differ at the very end
$value = 'x' * 300 + 'a'
$other = 'x' * 300 + 'b'

# Act
$text = & $module { param($Value, $Other) Format-TestValue -Value $Value -Other $Other } $value $other

# Assert
Assert-Equal -Expected ('...' + 'x' * 238 + 'a"') -Actual $text `
    -Message 'A difference at the end shows the end, marked as cut at the start'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - long values that differ in the middle
$value = 'x' * 1000
$other = 'x' * 500 + 'y' * 500

# Act
$valueText = & $module { param($Value, $Other) Format-TestValue -Value $Value -Other $Other } $value $other
$otherText = & $module { param($Value, $Other) Format-TestValue -Value $Value -Other $Other } $other $value

# Assert
Assert-Equal -Expected ('...' + 'x' * 240 + '...') -Actual $valueText `
    -Message 'A difference in the middle shows a window around it, marked as cut at both ends'
Assert-Equal -Expected ('...' + 'x' * 40 + 'y' * 200 + '...') -Actual $otherText `
    -Message 'with a little of what came before the difference'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one long value the start of the other
$value = 'x' * 300
$other = 'x' * 600

# Act
$text = & $module { param($Value, $Other) Format-TestValue -Value $Value -Other $Other } $value $other

# Assert
Assert-Equal -Expected ('...' + 'x' * 239 + '"') -Actual $text `
    -Message 'A value that ends where the other goes on shows its end'

exit (Complete-TestRun)
