#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - blank line, a full box, blank line
$lines = Get-HostOutput { Write-Banner 'BUILD FAILED' }

# Assert
Assert-Equal -Expected 5 -Actual $lines.Count -Message 'Write-Banner renders five lines: blank, top border, text, bottom border, blank'
Assert-Equal -Expected '' -Actual $lines[0] -Message 'A blank line opens the banner'
Assert-Equal -Expected '' -Actual $lines[4] -Message 'A blank line closes the banner'
Assert-That -Condition ($lines[1].StartsWith('┌') -and $lines[1].EndsWith('┐')) -Message 'The top border has both corners'
Assert-That -Condition ($lines[3].StartsWith('└') -and $lines[3].EndsWith('┘')) -Message 'The bottom border has both corners'
Assert-That -Condition ($lines[2].StartsWith('│') -and $lines[2].EndsWith('│')) -Message 'The text line has a side character on both edges'
Assert-That -Condition ($lines[2] -like '│ BUILD FAILED*') -Message 'The text line is left-justified'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - embedded newlines grow the banner vertically
$multiline = Get-HostOutput { Write-Banner "first line`nsecond line" }

# Assert
Assert-Equal -Expected 6 -Actual $multiline.Count -Message 'Two embedded lines produce a six-line banner (blank, top, 2 lines, bottom, blank)'
Assert-That -Condition ($multiline[2] -like '│ first line*') -Message 'The first embedded line renders on its own row'
Assert-That -Condition ($multiline[3] -like '│ second line*') -Message 'The second embedded line renders on its own row'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - -Trim narrows the box to fit short text
$normal = Get-HostOutput { Write-Banner 'hi' }
$trimmed = Get-HostOutput { Write-Banner 'hi' -Trim }

# Assert
Assert-That -Condition ($trimmed[1].Length -lt $normal[1].Length) -Message '-Trim produces a narrower box than the full-width default for short text'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - text far too long for any reasonable console
# wraps instead of running past it
$longText = (1..80 | ForEach-Object { 'word' }) -join ' '
$wrapped = Get-HostOutput { Write-Banner $longText }

# Assert
Assert-That -Condition ($wrapped.Count -gt 5) -Message 'Text longer than the console width wraps onto extra lines'

exit (Complete-TestRun)
