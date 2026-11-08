#Requires -Version 7.4

using namespace System.Collections.Generic

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$cases = @(
    @{ Value = @(1, 2); Expected = $true }
    @{ Value = [List[int]]@(1); Expected = $true }
    @{ Value = 'text'; Expected = $false }
    @{ Value = @{ a = 1 }; Expected = $false }
    @{ Value = 7; Expected = $false }
    @{ Value = $null; Expected = $false }
)

# Act
$answers = foreach ($case in $cases) {
    & $module { param($v) Test-FieldList -Value $v } $case.Value
}

# Assert
Assert-Equal -Expected @($cases.ForEach('Expected')) -Actual @($answers) `
    -Message 'An array or a typed list is a list; text, a dictionary, a number and $null are not'

exit (Complete-TestRun)
