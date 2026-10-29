#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$plain = & $module { Get-VisibleLength -Text 'abc' }
$empty = & $module { Get-VisibleLength -Text '' }

# Assert
Assert-Equal -Expected 3 -Actual $plain -Message 'Plain text is as long as it has characters'
Assert-Equal -Expected 0 -Actual $empty -Message 'and empty text is 0'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$colored = & $module { Get-VisibleLength -Text "`e[31mabc`e[0m" }
$rich = & $module { Get-VisibleLength -Text "`e[1;38;5;208mx`e[m y" }

# Assert
Assert-Equal -Expected 3 -Actual $colored -Message 'A color code takes no room on screen, so it is not counted'
Assert-Equal -Expected 3 -Actual $rich -Message 'nor is one with several parameters, or none'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$colonForm = & $module { Get-VisibleLength -Text "`e[38:5:208mX`e[0m" }

# Assert
Assert-Equal -Expected 1 -Actual $colonForm -Message 'A color code with colon-separated parameters takes no room either'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$styleText = $PSStyle.FormatHyperlink('X', 'https://example.com/')
$bellText = "`e]8;;https://example.com/`aX`e]8;;`a"

# Act
$styleLink = & $module { param($text) Get-VisibleLength -Text $text } $styleText
$bellLink = & $module { param($text) Get-VisibleLength -Text $text } $bellText

# Assert
Assert-Equal -Expected 1 -Actual $styleLink -Message 'A $PSStyle hyperlink counts only its visible text'
Assert-Equal -Expected 1 -Actual $bellLink -Message 'and so does one whose sequences end with a bell'

exit (Complete-TestRun)
