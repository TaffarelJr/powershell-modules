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
# Arrange - a stand-in Install-Module, so nothing is downloaded or installed,
# and a module that is not installed
$sandbox = New-RequiredModulesSandbox
Use-FakeInstaller -Module $module
$missing = [PSCustomObject]@{ Name = 'Probe.Missing'; MinimumVersion = [Version]'5.0.0' }

# Act
Assert-FakeInstaller -Module $module
Install-RequiredModule -Module $missing
$call = $global:FakeInstallCalls[0]

# Assert
Assert-Equal -Expected 1 -Actual $global:FakeInstallCalls.Count `
    -Message 'Install-RequiredModule calls through to Install-Module once'
Assert-Equal -Expected 'Probe.Missing' -Actual $call.Name -Message 'Passes the module name through'
Assert-Equal -Expected ([Version]'5.0.0') -Actual $call.MinimumVersion -Message 'Passes the minimum version through'
Assert-Equal -Expected 'CurrentUser' -Actual $call.Scope -Message 'Always installs at CurrentUser scope'
Assert-Equal -Expected $true -Actual $call.Force -Message 'Always forces the install'
Assert-Equal -Expected $true -Actual $call.SkipPublisherCheck -Message 'Always skips the publisher check'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - several modules, given as an array, through the pipeline, and by position
$global:FakeInstallCalls.Clear()
$others = @(
    [PSCustomObject]@{ Name = 'Probe.Alpha'; MinimumVersion = [Version]'1.0.0' }
    [PSCustomObject]@{ Name = 'Probe.Beta'; MinimumVersion = [Version]'2.0.0' }
)

# Act
Assert-FakeInstaller -Module $module
Install-RequiredModule -Module $others
$fromArray = $global:FakeInstallCalls.Name -join ', '
$global:FakeInstallCalls.Clear()
Assert-FakeInstaller -Module $module
$others | Install-RequiredModule
$fromPipeline = $global:FakeInstallCalls.Name -join ', '
$global:FakeInstallCalls.Clear()
Assert-FakeInstaller -Module $module
Install-RequiredModule $others
$fromPosition = $global:FakeInstallCalls.Name -join ', '

# Assert
Assert-Equal -Expected 'Probe.Alpha, Probe.Beta' -Actual $fromArray `
    -Message 'An array given as -Module installs every module, in order'
Assert-Equal -Expected 'Probe.Alpha, Probe.Beta' -Actual $fromPipeline `
    -Message 'Piped modules install every module, in order'
Assert-Equal -Expected 'Probe.Alpha, Probe.Beta' -Actual $fromPosition `
    -Message 'Modules given by position install every module, in order'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one module installed at a good enough version, one installed too old,
# and one loaded by its path only
$global:FakeInstallCalls.Clear()
New-FakeModule -Root $sandbox -Name 'Probe.Present' -Version '2.0.0'
New-FakeModule -Root $sandbox -Name 'Probe.Old' -Version '1.0.0'
New-FakeModule -Root "$sandbox-outside" -Name 'Probe.Loose' -Version '3.0.0'
$null = Import-Module (Join-Path "$sandbox-outside" 'Probe.Loose' '3.0.0' 'Probe.Loose.psd1') -Global -Force
$mixed = @(
    [PSCustomObject]@{ Name = 'Probe.Loose'; MinimumVersion = [Version]'3.0.0' }
    [PSCustomObject]@{ Name = 'Probe.Old'; MinimumVersion = [Version]'2.0.0' }
    [PSCustomObject]@{ Name = 'Probe.Present'; MinimumVersion = [Version]'2.0.0' }
)

# Act
Assert-FakeInstaller -Module $module
Install-RequiredModule -Module $mixed

# Assert
Assert-Equal -Expected 'Probe.Old' -Actual ($global:FakeInstallCalls.Name -join ', ') `
    -Message 'Only the module that is not satisfied is installed; a satisfied one is not downloaded again'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an empty list, as an empty manifest gives
$global:FakeInstallCalls.Clear()

# Act
Assert-FakeInstaller -Module $module
Install-RequiredModule -Module @()

# Assert
Assert-Equal -Expected 0 -Actual $global:FakeInstallCalls.Count `
    -Message 'An empty list installs nothing and is not refused'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module with a name and no minimum version, not installed
$global:FakeInstallCalls.Clear()
$any = [PSCustomObject]@{ Name = 'Probe.Any' }

# Act
Assert-FakeInstaller -Module $module
Install-RequiredModule -Module $any

# Assert
Assert-Equal -Expected 1 -Actual $global:FakeInstallCalls.Count -Message 'A name alone is installed'
Assert-That -Condition ($null -eq $global:FakeInstallCalls[0].MinimumVersion) `
    -Message 'with no minimum version, so the newest is the one installed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same module, now installed at some version
$global:FakeInstallCalls.Clear()
New-FakeModule -Root $sandbox -Name 'Probe.Any' -Version '0.0.1'

# Act
Assert-FakeInstaller -Module $module
Install-RequiredModule -Module $any

# Assert
Assert-Equal -Expected 0 -Actual $global:FakeInstallCalls.Count `
    -Message 'A name alone is satisfied by any installed version, so nothing is installed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an install that fails the way Install-Module does: a non-terminating error
$global:FakeInstallCalls.Clear()
$global:FakeInstallFailure = "No match was found for the specified search criteria and module name 'Probe.Missing'."
Assert-FakeInstaller -Module $module

# Act / Assert
Assert-Throws -ScriptBlock {
    Install-RequiredModule -Module $missing
} -MessageLike "*No match was found*'Probe.Missing'*" `
    -Message 'A failed install throws with the installer''s own message instead of carrying on as if it worked'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the stand-in Install-Module shadowed by a function of the same
# name, as a real installer imported later would shadow it; nothing calls it
$global:FakeInstallFailure = $null
Use-FakeInstaller -Module $module
function global:Install-Module { throw 'The shadowing Install-Module is never called.' }

# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-FakeInstaller -Module $module
} -MessageLike '*Install-Module resolves to a function outside any module, not the test stand-in*' `
    -Message 'The guard refuses an Install-Module that is not the stand-in'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same for Install-PSResource
Remove-Item -LiteralPath function:global:Install-Module
Use-FakeInstaller -Module $module
function global:Install-PSResource { throw 'The shadowing Install-PSResource is never called.' }

# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-FakeInstaller -Module $module
} -MessageLike '*Install-PSResource resolves to a function outside any module, not the test stand-in*' `
    -Message 'and an Install-PSResource that is not the stand-in'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an alias named Install-Module, which wins over any function
Remove-Item -LiteralPath function:global:Install-PSResource
Use-FakeInstaller -Module $module
Set-Alias -Name Install-Module -Value Get-Date -Scope Global

# Act / Assert
Assert-Throws -ScriptBlock {
    Assert-FakeInstaller -Module $module
} -MessageLike '*Install-Module resolves to an alias of Get-Date, not the test stand-in*' `
    -Message 'and an alias that takes the place of the stand-in'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no stand-in at all, with the real installer on PSModulePath but
# not loaded
Remove-Item -LiteralPath alias:Install-Module
Use-FakeInstaller -Module $module
Remove-Module -Name FakeInstaller -Force

# Act
$goneMessage = try {
    Assert-FakeInstaller -Module $module
}
catch {
    $_.Exception.Message
}
$loadedInstallers = @(Get-Module -Name PowerShellGet, Microsoft.PowerShell.PSResourceGet)

# Assert
Assert-That -Condition ($goneMessage -like '*Install-Module resolves to nothing, not the test stand-in*') `
    -Message 'and a session where the stand-in is gone'
Assert-Equal -Expected 0 -Actual $loadedInstallers.Count -Message 'and looking does not load the real installer'

# Cleanup
Remove-Module -Name 'Probe.*' -Force
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
