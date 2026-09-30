#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$text = & $module { Format-MessageText 'built it' }
$padded = & $module { Format-MessageText '  built it  ' }

# Assert
Assert-Equal -Expected 'built it' -Actual $text -Message 'Text is returned as given'
Assert-Equal -Expected '  built it  ' -Actual $padded -Message 'including the space around it'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$empty = & $module { Format-MessageText '' }
$blank = & $module { Format-MessageText "  `t " }

# Assert
Assert-Equal -Expected '(no message)' -Actual $empty -Message 'Empty text becomes the placeholder'
Assert-Equal -Expected '(no message)' -Actual $blank -Message 'and so does text that is only whitespace'

exit (Complete-TestRun)
