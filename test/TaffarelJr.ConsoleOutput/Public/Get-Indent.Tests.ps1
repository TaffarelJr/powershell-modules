#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange - nothing pushed
Reset-ConsoleOutputState -Module $module

# Act
$indent = Get-Indent

# Assert
Assert-Equal -Expected 0 -Actual $indent -Message 'Get-Indent is 0 with nothing pushed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Push-Indent -Width 6

# Act
$indent = Get-Indent

# Assert
Assert-Equal -Expected 6 -Actual $indent -Message 'Get-Indent reflects a single pushed width'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module
Push-Indent -Width 2
Push-Indent -Width 3
Push-Indent -Width 4

# Act
$indent = Get-Indent

# Assert
Assert-Equal -Expected 9 -Actual $indent -Message 'Get-Indent sums every level on the stack'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$declared = (Get-Command Get-Indent).OutputType.ForEach('Type')

# Assert
Assert-Equal -Expected @([int]) -Actual @($declared) -Message 'Get-Indent declares that it returns an int'

exit (Complete-TestRun)
