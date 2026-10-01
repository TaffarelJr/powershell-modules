#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - CRLF content is detected as CRLF
Assert-Equal -Expected "`r`n" -Actual (Get-LineEnding -Content "a`r`nb`r`n") -Message 'CRLF content is detected as CRLF'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - LF-only content is detected as LF
Assert-Equal -Expected "`n" -Actual (Get-LineEnding -Content "a`nb`n") -Message 'LF-only content is detected as LF'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a single CRLF among bare LFs still counts as CRLF
Assert-Equal -Expected "`r`n" -Actual (Get-LineEnding -Content "a`nb`r`n") -Message 'Any CRLF present wins over a bare LF elsewhere'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - content with no line break falls back to the platform default
Assert-Equal -Expected ([Environment]::NewLine) -Actual (Get-LineEnding -Content 'no newline here') -Message 'Content with no line break falls back to the platform default'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - empty content falls back to the platform default too
Assert-Equal -Expected ([Environment]::NewLine) -Actual (Get-LineEnding -Content '') -Message 'Empty content falls back to the platform default'

exit (Complete-TestRun)
