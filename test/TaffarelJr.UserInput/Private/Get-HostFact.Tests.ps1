#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
$module = Get-Module TaffarelJr.UserInput

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act
$fact = & $module { Get-HostFact }

# Assert
Assert-Equal -Expected ([Environment]::GetCommandLineArgs()) -Actual $fact.CommandLine `
    -Message 'CommandLine is what this process was started with'
Assert-Equal -Expected ([Environment]::UserInteractive) -Actual $fact.UserInteractive `
    -Message 'UserInteractive is what the host says about a user being present'
Assert-Equal -Expected ([Console]::IsInputRedirected) -Actual $fact.InputRedirected `
    -Message 'InputRedirected says whether input comes from a pipe or a file'

exit (Complete-TestRun)
