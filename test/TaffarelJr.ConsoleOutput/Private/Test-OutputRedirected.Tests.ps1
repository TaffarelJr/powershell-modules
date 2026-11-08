#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
$module = Get-Module TaffarelJr.ConsoleOutput

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$expected = [Console]::IsOutputRedirected

# Act
$redirected = & $module { Test-OutputRedirected }

# Assert
Assert-Equal -Expected $expected -Actual $redirected `
    -Message 'The answer is whether this process''s standard output is redirected'

exit (Complete-TestRun)
