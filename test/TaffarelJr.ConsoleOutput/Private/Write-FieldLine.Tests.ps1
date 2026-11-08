#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ConsoleOutputTestHelper.ps1')
$module = Get-Module TaffarelJr.ConsoleOutput
#───────────────────────────────────────────────────────────────────────────────
# Arrange
Reset-ConsoleOutputState -Module $module

# Act
$line = @(Get-HostMessage { & $module { Write-FieldLine -Name 'Branch' -Value 'main' -Budget 10 } })

# Assert
Assert-Equal -Expected @('  ' + 'Branch:'.PadRight(9) + ' main') -Actual @($line.Message) `
    -Message 'The value starts the budget''s width in from the indent'
Assert-Equal -Expected 'Gray' -Actual $line[0].Color -Message 'in gray'

exit (Complete-TestRun)
