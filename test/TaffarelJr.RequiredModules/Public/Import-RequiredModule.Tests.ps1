#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.UserInput/TaffarelJr.UserInput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a real, always-present built-in module,
# so this exercises a genuine Import-Module call rather than a shadowed one
Remove-Module -Name Microsoft.PowerShell.Utility -Force -ErrorAction SilentlyContinue
$module = [PSCustomObject]@{ Name = 'Microsoft.PowerShell.Utility'; MinimumVersion = [Version]'3.0.0' }

# Act
Import-RequiredModule -Module $module

# Assert
$loaded = Get-Module -Name Microsoft.PowerShell.Utility
Assert-That -Condition ($null -ne $loaded) -Message 'The module is loaded after Import-RequiredModule'
Assert-That -Condition ($loaded.Version -ge [Version]'3.0.0') -Message 'The loaded version meets the requested minimum'

exit (Complete-TestRun)
