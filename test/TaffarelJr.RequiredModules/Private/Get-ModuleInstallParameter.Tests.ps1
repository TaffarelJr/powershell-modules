#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/Private/Get-ModuleInstallParameter.ps1')

# Arrange
$module = [pscustomobject]@{ Name = 'Pester'; MinimumVersion = [version]'5.0.0' }

# Act
$parameters = Get-ModuleInstallParameter -Module $module

# Assert
Assert-Equal -Expected 'Pester' -Actual $parameters.Name -Message 'Carries the module name'
Assert-Equal -Expected ([version]'5.0.0') -Actual $parameters.MinimumVersion -Message 'Carries the minimum version'
Assert-Equal -Expected 'CurrentUser' -Actual $parameters.Scope -Message 'Always scopes to CurrentUser'
Assert-Equal -Expected $true -Actual $parameters.Force -Message 'Always forces the install'
Assert-Equal -Expected $true -Actual $parameters.SkipPublisherCheck -Message 'Always skips the publisher check'

exit (Complete-TestRun)
