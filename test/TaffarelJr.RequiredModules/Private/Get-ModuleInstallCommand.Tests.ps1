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
$command = & $module { Get-ModuleInstallCommand @args } -Module $required
$parameters = & $module { Get-ModuleInstallParameter @args } -Module $required
$words = @($command -split ' ')
$named = @($words | Where-Object { $_ -like '-*' } | ForEach-Object { $_.Substring(1) })

# Assert
Assert-Equal `
    -Expected 'Install-Module -Name Pester -MinimumVersion 5.0.0 -Scope CurrentUser -Force -SkipPublisherCheck' `
    -Actual $command `
    -Message 'Renders a copy-pasteable Install-Module command'
Assert-Equal -Expected @($parameters.PSBase.Keys) -Actual $named `
    -Message 'Names exactly the parameters Install-RequiredModule passes, in the same order'

exit (Complete-TestRun)
