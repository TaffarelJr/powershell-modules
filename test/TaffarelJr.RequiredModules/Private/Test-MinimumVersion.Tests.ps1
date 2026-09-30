#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$modulePath = Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1'
$module = Import-Module $modulePath -Force -PassThru

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$cases = @(
    @{ Installed = '2.0.0'; Minimum = '1.0.0'; Expected = $true; Case = 'above the minimum' }
    @{ Installed = '2.0.0'; Minimum = '2.0.0'; Expected = $true; Case = 'exactly the minimum' }
    @{ Installed = '2.0.0'; Minimum = '2.0.1'; Expected = $false; Case = 'just below the minimum' }
    @{ Installed = '1.2.3.4'; Minimum = '1.2.3'; Expected = $true; Case = 'four parts against three' }
    @{ Installed = '5.0'; Minimum = '5.0.0'; Expected = $false; Case = 'two parts against the same three' }
    @{ Installed = '5.0.0'; Minimum = '5.0'; Expected = $true; Case = 'three parts against the same two' }
)

foreach ($case in $cases) {
    # Act
    $satisfied = & $module { Test-MinimumVersion @args } `
        -InstalledVersion ([Version]$case.Installed) `
        -MinimumVersion ([Version]$case.Minimum)

    # Assert
    Assert-Equal -Expected $case.Expected -Actual $satisfied `
        -Message "$($case.Installed) against $($case.Minimum), $($case.Case), is $($case.Expected)"
}

#───────────────────────────────────────────────────────────────────────────────
# Act - nothing installed
$none = & $module { Test-MinimumVersion @args } -InstalledVersion $null -MinimumVersion ([Version]'1.0.0')

# Assert
Assert-Equal -Expected $false -Actual $none -Message 'No installed version never satisfies a minimum'

#───────────────────────────────────────────────────────────────────────────────
# Act - no minimum at all
$anyVersion = & $module { Test-MinimumVersion @args } -InstalledVersion ([Version]'0.0.1') -MinimumVersion $null
$noneAnyVersion = & $module { Test-MinimumVersion @args } -InstalledVersion $null -MinimumVersion $null

# Assert
Assert-Equal -Expected $true -Actual $anyVersion -Message 'With no minimum, any installed version satisfies it'
Assert-Equal -Expected $false -Actual $noneAnyVersion -Message 'but a module that is not installed does not'

exit (Complete-TestRun)
