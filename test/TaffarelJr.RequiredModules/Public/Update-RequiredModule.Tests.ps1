#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidGlobalVars',
    '',
    Justification = 'The test sets and reads the caller-session state the code under test uses.')]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - stand-ins for the installer and the updater, so nothing is downloaded,
# a module installed at 2.0.0, and one that is not installed
$sandbox = New-RequiredModulesSandbox
Use-FakeInstaller -Module $module
New-FakeModule -Root $sandbox -Name 'Probe.Present' -Version '2.0.0'
$present = [PSCustomObject]@{ Name = 'Probe.Present'; MinimumVersion = [Version]'1.0.0' }
$missing = [PSCustomObject]@{ Name = 'Probe.Missing'; MinimumVersion = [Version]'5.0.0' }

# Act
Assert-FakeInstaller -Module $module
Update-RequiredModule -Module $present

# Assert
Assert-Equal -Expected 1 -Actual $global:FakeUpdateCalls.Count `
    -Message 'An installed module is updated, though it already meets its minimum'
Assert-Equal -Expected 'Probe.Present' -Actual $global:FakeUpdateCalls[0].Name -Message 'by name'
Assert-Equal -Expected $true -Actual $global:FakeUpdateCalls[0].Force -Message 'without a question'
Assert-Equal -Expected 0 -Actual $global:FakeInstallCalls.Count -Message 'and nothing is installed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$global:FakeUpdateCalls.Clear()

# Act
Assert-FakeInstaller -Module $module
Update-RequiredModule -Module $missing

# Assert
Assert-Equal -Expected 0 -Actual $global:FakeUpdateCalls.Count -Message 'A module that is not installed is not updated'
Assert-Equal -Expected 1 -Actual $global:FakeInstallCalls.Count -Message 'it is installed, at the newest version'
Assert-Equal -Expected 'Probe.Missing' -Actual $global:FakeInstallCalls[0].Name -Message 'by name'
Assert-Equal -Expected 'CurrentUser' -Actual $global:FakeInstallCalls[0].Scope -Message 'for the current user'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - several modules, given as an array, through the pipeline, and by position
$global:FakeInstallCalls.Clear()
$global:FakeUpdateCalls.Clear()
$several = @($present, $missing)

# Act
Assert-FakeInstaller -Module $module
Update-RequiredModule -Module $several
$fromArray = "$($global:FakeUpdateCalls.Name -join ', ') | $($global:FakeInstallCalls.Name -join ', ')"
$global:FakeInstallCalls.Clear()
$global:FakeUpdateCalls.Clear()
$several | Update-RequiredModule
$fromPipeline = "$($global:FakeUpdateCalls.Name -join ', ') | $($global:FakeInstallCalls.Name -join ', ')"
$global:FakeInstallCalls.Clear()
$global:FakeUpdateCalls.Clear()
Update-RequiredModule $several
$fromPosition = "$($global:FakeUpdateCalls.Name -join ', ') | $($global:FakeInstallCalls.Name -join ', ')"

# Assert
Assert-Equal -Expected 'Probe.Present | Probe.Missing' -Actual $fromArray `
    -Message 'An array given as -Module updates what is installed and installs what is not'
Assert-Equal -Expected 'Probe.Present | Probe.Missing' -Actual $fromPipeline -Message 'Piped modules do the same'
Assert-Equal -Expected 'Probe.Present | Probe.Missing' -Actual $fromPosition `
    -Message 'and so do modules given by position'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module with a name and no minimum version
$global:FakeUpdateCalls.Clear()
$anyVersion = [PSCustomObject]@{ Name = 'Probe.Present' }

# Act
Assert-FakeInstaller -Module $module
Update-RequiredModule -Module $anyVersion

# Assert
Assert-Equal -Expected @('Probe.Present') -Actual @($global:FakeUpdateCalls | ForEach-Object Name) `
    -Message 'A name alone is updated like any other module'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an empty list, as an empty manifest gives
$global:FakeInstallCalls.Clear()
$global:FakeUpdateCalls.Clear()

# Act
Assert-FakeInstaller -Module $module
$empty = @(Update-RequiredModule -Module @())

# Assert
Assert-Equal -Expected 0 -Actual ($global:FakeUpdateCalls.Count + $global:FakeInstallCalls.Count) `
    -Message 'An empty list updates and installs nothing, and is not refused'
Assert-Equal -Expected 0 -Actual $empty.Count -Message 'and returns nothing'

# Cleanup
Remove-Module -Name 'Probe.*' -Force -ErrorAction Ignore
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
