#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - blank line, rule, left-justified text, rule, blank line
$lines = Get-HostOutput { Write-Header 'Build' }

# Assert
Assert-Equal -Expected 5 -Actual $lines.Count -Message 'Write-Header renders five lines: blank, rule, text, rule, blank'
Assert-Equal -Expected '' -Actual $lines[0] -Message 'A blank line opens the header'
Assert-Equal -Expected '' -Actual $lines[4] -Message 'A blank line closes the header'
Assert-Equal -Expected $lines[1] -Actual $lines[3] -Message 'The top and bottom rules match'
Assert-That -Condition ($lines[1] -notmatch '[│┌┐└┘]') -Message 'A header has no side border characters'
Assert-That -Condition ($lines[2] -like 'Build*') -Message 'The text line is left-justified'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - embedded newlines grow the header vertically
$multiline = Get-HostOutput { Write-Header "first line`nsecond line" }

# Assert
Assert-Equal -Expected 6 -Actual $multiline.Count -Message 'Two embedded lines produce a six-line header (blank, rule, 2 lines, rule, blank)'
Assert-That -Condition ($multiline[2] -like 'first line*') -Message 'The first embedded line renders on its own row'
Assert-That -Condition ($multiline[3] -like 'second line*') -Message 'The second embedded line renders on its own row'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Trim narrows the rule to fit short text
$normal = Get-HostOutput { Write-Header 'hi' }
$trimmed = Get-HostOutput { Write-Header 'hi' -Trim }

# Assert
Assert-That -Condition ($trimmed[1].Length -lt $normal[1].Length) -Message '-Trim produces a narrower rule than the full-width default for short text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - text far too long for any reasonable console
# wraps instead of running past it
$longText = (1..80 | ForEach-Object { 'word' }) -join ' '
$wrapped = Get-HostOutput { Write-Header $longText }

# Assert
Assert-That -Condition ($wrapped.Count -gt 5) -Message 'Text longer than the console width wraps onto extra lines'

exit (Complete-TestRun)
