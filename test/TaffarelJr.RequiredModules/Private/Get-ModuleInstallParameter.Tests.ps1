#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1'
$module = Import-Module $modulePath -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$required = [PSCustomObject]@{
    Name           = 'Pester'
    MinimumVersion = [Version]'5.0.0'
}

# Act
$parameters = & $module { Get-ModuleInstallParameter @args } -Module $required

# Assert
Assert-Equal -Expected 'Pester' -Actual $parameters.Name -Message 'Carries the module name'
Assert-Equal -Expected ([Version]'5.0.0') -Actual $parameters.MinimumVersion -Message 'Carries the minimum version'
Assert-Equal -Expected 'CurrentUser' -Actual $parameters.Scope -Message 'Always scopes to CurrentUser'
Assert-Equal -Expected $true -Actual $parameters.Force -Message 'Always forces the install'
Assert-Equal -Expected $true -Actual $parameters.SkipPublisherCheck -Message 'Always skips the publisher check'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module with no minimum version
$any = [PSCustomObject]@{
    Name           = 'Pester'
    MinimumVersion = $null
}

# Act
$anyParameters = & $module { Get-ModuleInstallParameter @args } -Module $any

# Assert
Assert-Equal -Expected @('Name', 'Scope', 'Force', 'SkipPublisherCheck') -Actual @($anyParameters.PSBase.Keys) `
    -Message 'Leaves the minimum version out, so the newest version is installed'

exit (Complete-TestRun)
