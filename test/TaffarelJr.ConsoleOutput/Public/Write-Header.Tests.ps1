#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force

# Arrange / Act - rule, centered text, rule; no side border characters
$lines = Get-HostOutput { Write-Header 'Build' }

# Assert
Assert-Equal -Expected 3 -Actual $lines.Count -Message 'Write-Header renders three lines: rule, text, rule'
Assert-Equal -Expected $lines[0] -Actual $lines[2] -Message 'The top and bottom rules match'
Assert-That -Condition ($lines[0] -notmatch '[│┌┐└┘]') -Message 'A header has no side border characters'
Assert-That -Condition ($lines[1] -like '*Build*') -Message 'The middle line carries the given text'

# Arrange / Act - embedded newlines grow the header vertically
$multiline = Get-HostOutput { Write-Header "first line`nsecond line" }

# Assert
Assert-Equal -Expected 4 -Actual $multiline.Count -Message 'Two embedded lines produce a four-line header (rule, 2 lines, rule)'
Assert-That -Condition ($multiline[1] -like '*first line*') -Message 'The first embedded line renders on its own row'
Assert-That -Condition ($multiline[2] -like '*second line*') -Message 'The second embedded line renders on its own row'

# Arrange / Act - -Trim narrows the rule to fit short text
$normal = Get-HostOutput { Write-Header 'hi' }
$trimmed = Get-HostOutput { Write-Header 'hi' -Trim }

# Assert
Assert-That -Condition ($trimmed[0].Length -lt $normal[0].Length) -Message '-Trim produces a narrower rule than the full-width default for short text'

# Arrange / Act - text far too long for any reasonable console
# wraps instead of running past it
$longText = (1..80 | ForEach-Object { 'word' }) -join ' '
$wrapped = Get-HostOutput { Write-Header $longText }

# Assert
Assert-That -Condition ($wrapped.Count -gt 3) -Message 'Text longer than the console width wraps onto extra lines'

exit (Complete-TestRun)
