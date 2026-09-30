#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - every kind of line break
$lines = @(& $module { Split-TextLine -Text "a`r`nb`rc`nd" })

# Assert
Assert-Equal -Expected @('a', 'b', 'c', 'd') -Actual $lines -Message 'CRLF, a lone CR and a lone LF each end one line'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - blank lines
$blank = @(& $module { Split-TextLine -Text "a`n`nb`n" })
$empty = @(& $module { Split-TextLine -Text '' })

# Assert
Assert-Equal -Expected @('a', '', 'b', '') -Actual $blank `
    -Message 'A blank line, and the one after a final break, are kept'
Assert-Equal -Expected @('') -Actual $empty -Message 'Empty text is one empty line, never none'

exit (Complete-TestRun)
