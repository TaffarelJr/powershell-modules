#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$original = [Console]::OutputEncoding
$other = [Text.Encoding]::GetEncoding(437)

# Act
try {
    & $module { param($Encoding) Set-ConsoleEncoding -Encoding $Encoding } $other
    $set = [Console]::OutputEncoding.CodePage
}
finally {
    [Console]::OutputEncoding = $original
}

# Assert
Assert-Equal -Expected 437 -Actual $set -Message 'The console''s output encoding is the one given'

exit (Complete-TestRun)
