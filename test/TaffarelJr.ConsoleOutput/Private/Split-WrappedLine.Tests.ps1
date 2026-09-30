#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/Private/Split-WrappedLine.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - text that already fits is returned as a single line
$result = Split-WrappedLine -Text 'short' -Width 20

# Assert
Assert-Equal -Expected 1 -Actual $result.Count -Message 'Text that fits within Width stays on one line'
Assert-Equal -Expected 'short' -Actual $result[0] -Message 'The single line is returned unchanged'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - embedded CR/LF always starts a new line,
# even when the combined text would otherwise fit
$result = Split-WrappedLine -Text "one`ntwo" -Width 20

# Assert
Assert-Equal -Expected 2 -Actual $result.Count -Message 'An embedded newline always breaks the line'
Assert-Equal -Expected 'one' -Actual $result[0] -Message 'The first embedded line is preserved exactly'
Assert-Equal -Expected 'two' -Actual $result[1] -Message 'The second embedded line is preserved exactly'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a paragraph longer than Width wraps at word boundaries
$result = Split-WrappedLine -Text 'one two three four' -Width 7

# Assert
Assert-That -Condition ($result.Count -gt 1) -Message 'A paragraph longer than Width wraps onto more than one line'
foreach ($line in $result) {
    Assert-That -Condition ($line.Length -le 7) -Message "Wrapped line '$line' fits within the given Width"
}
Assert-Equal -Expected 'one two three four' -Actual ($result -join ' ') -Message 'Rejoining the wrapped lines recovers the original words in order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a single word longer than Width is left to overflow
# rather than split mid-word
$result = Split-WrappedLine -Text 'supercalifragilisticexpialidocious' -Width 10

# Assert
Assert-Equal -Expected 1 -Actual $result.Count -Message 'A single overlong word is not split mid-word'
Assert-Equal -Expected 'supercalifragilisticexpialidocious' -Actual $result[0] -Message 'The overlong word is returned whole'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - empty text
$result = Split-WrappedLine -Text '' -Width 10

# Assert
Assert-Equal -Expected 1 -Actual $result.Count -Message 'Empty text still returns one (empty) line, never zero'
Assert-Equal -Expected '' -Actual $result[0] -Message 'The single line is empty'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - the return value is always an array, even for one line,
# so a caller can safely index or count it without unwrapping surprises
$result = Split-WrappedLine -Text 'x' -Width 10

# Assert
Assert-That -Condition ($result -is [array]) -Message 'A single-line result is still returned as an array'

exit (Complete-TestRun)
