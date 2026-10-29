#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1'
$module = Import-Module $modulePath -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange - with a documentation link
$withDocs = [PSCustomObject]@{
    Name             = 'Pester'
    MinimumVersion   = [Version]'5.0.0'
    DocumentationUrl = 'https://pester.dev'
}

# Act
$message = & $module { Get-MissingModuleMessage @args } -Module $withDocs

# Assert
Assert-That -Condition ($message -like '*Pester*5.0.0*required but not installed*') `
    -Message 'Names the module, its minimum version, and that it is missing'
Assert-That -Condition ($message -like '*Install-Module -Name Pester*') -Message 'Includes the install command'
Assert-That -Condition ($message -like '*https://pester.dev*') `
    -Message 'Includes the documentation link when one is given'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - without a documentation link
$withoutDocs = [PSCustomObject]@{
    Name             = 'Pester'
    MinimumVersion   = [Version]'5.0.0'
    DocumentationUrl = $null
}

# Act
$plainMessage = & $module { Get-MissingModuleMessage @args } -Module $withoutDocs

# Assert
Assert-That -Condition ($plainMessage -notlike '*Docs:*') `
    -Message 'Omits the docs line entirely when there is no documentation link'

#───────────────────────────────────────────────────────────────────────────────
# Act - an older version is installed
$tooOld = & $module { Get-MissingModuleMessage @args } -Module $withoutDocs -InstalledVersion ([Version]'3.4.0')

# Assert
Assert-That -Condition ($tooOld -like '*Pester 5.0.0 or later is required, but only 3.4.0 is installed*') `
    -Message 'Says which version is there instead of calling the module not installed'
Assert-That -Condition ($tooOld -notlike '*not installed*') `
    -Message 'Does not call a module that is installed not installed'
Assert-That -Condition ($tooOld -like '*Install-Module -Name Pester*') -Message 'Still includes the install command'

#───────────────────────────────────────────────────────────────────────────────
# Act - no installed version, given explicitly as $null
$nothingInstalled = & $module { Get-MissingModuleMessage @args } -Module $withoutDocs -InstalledVersion $null

# Assert
Assert-That -Condition ($nothingInstalled -like '*required but not installed*') `
    -Message 'A $null installed version reads as not installed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module with no minimum version
$any = [PSCustomObject]@{
    Name             = 'Pester'
    MinimumVersion   = $null
    DocumentationUrl = $null
}

# Act
$anyMessage = & $module { Get-MissingModuleMessage @args } -Module $any

# Assert
Assert-That -Condition ($anyMessage -like 'Pester is required but not installed.*') `
    -Message 'A module with no minimum is named without a version, and called not installed'
Assert-That -Condition ($anyMessage -notlike '*or later*') -Message 'and without "or later"'

exit (Complete-TestRun)
