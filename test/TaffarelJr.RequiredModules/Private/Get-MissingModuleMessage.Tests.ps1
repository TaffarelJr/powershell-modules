#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/Private/Get-ModuleInstallCommand.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/Private/Get-MissingModuleMessage.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - with a documentation link
$withDocs = [PSCustomObject]@{ Name = 'Pester'; MinimumVersion = [Version]'5.0.0'; DocumentationUrl = 'https://pester.dev' }

# Act
$message = Get-MissingModuleMessage -Module $withDocs

# Assert
Assert-That -Condition ($message -like '*Pester*5.0.0*required but not installed*') -Message 'Names the module, its minimum version, and that it is missing'
Assert-That -Condition ($message -like '*Install-Module -Name Pester*') -Message 'Includes the install command'
Assert-That -Condition ($message -like '*https://pester.dev*') -Message 'Includes the documentation link when one is given'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - without a documentation link
$withoutDocs = [PSCustomObject]@{ Name = 'Pester'; MinimumVersion = [Version]'5.0.0'; DocumentationUrl = $null }

# Act
$plainMessage = Get-MissingModuleMessage -Module $withoutDocs

# Assert
Assert-That -Condition ($plainMessage -notlike '*Docs:*') -Message 'Omits the docs line entirely when there is no documentation link'

exit (Complete-TestRun)
