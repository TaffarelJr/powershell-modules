#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/Private/Get-ModuleInstallCommand.ps1')

# Arrange
$module = [pscustomobject]@{ Name = 'Pester'; MinimumVersion = [version]'5.0.0' }

# Act
$command = Get-ModuleInstallCommand -Module $module

# Assert
Assert-Equal -Expected 'Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser' -Actual $command -Message 'Renders a copy-pasteable Install-Module command'

exit (Complete-TestRun)
