#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$list = & $module { Join-FieldItem -Value @(1, @(2, 3)) }
$text = & $module { Join-FieldItem -Value 'plain' }
$nothing = & $module { Join-FieldItem -Value $null }

# Assert
Assert-Equal -Expected '1, 2, 3' -Actual $list -Message 'A list is joined with a comma and a space, flattened'
Assert-Equal -Expected 'plain' -Actual $text -Message 'Text is returned as it is'
Assert-Equal -Expected '' -Actual $nothing -Message 'and $null as empty text'

exit (Complete-TestRun)
