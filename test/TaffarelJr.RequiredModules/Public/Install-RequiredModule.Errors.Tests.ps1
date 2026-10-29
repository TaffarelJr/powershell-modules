#Requires -Version 7.4
using namespace System.Management.Automation

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
# Arrange - two modules to install, and an installer that fails
$sandbox = New-RequiredModulesSandbox
Use-FakeInstaller -Module $module
$global:FakeInstallFailure = 'Gallery unreachable'
$first = [PSCustomObject]@{ Name = 'Probe.First'; MinimumVersion = [Version]'1.0.0' }
$second = [PSCustomObject]@{ Name = 'Probe.Second'; MinimumVersion = [Version]'1.0.0' }

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    $global:FakeInstallCalls.Clear()

    # Act - a failing record, whose caller asked for errors to be hidden
    $caught = $null
    try {
        $first, $second | Install-RequiredModule -ErrorAction $preference
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected @('Probe.First') -Actual @($global:FakeInstallCalls | ForEach-Object Name) `
        -Message "Under -ErrorAction $preference a failing record stops the pipeline, so the next is not installed"
    Assert-Equal `
        -Expected 'Microsoft.PowerShell.Commands.WriteErrorException,Install-Module,Install-RequiredModule' `
        -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the failure is still raised, as a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$global:FakeInstallCalls.Clear()
$caught = $null
try {
    $first, $second | Install-RequiredModule
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'Microsoft.PowerShell.Commands.WriteErrorException,Install-Module,Install-RequiredModule' `
    -Actual $caught.FullyQualifiedErrorId `
    -Message 'A failed install raises a terminating error whose ID names the failure and the commands'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with a category a caller can act on'
Assert-Equal -Expected $null -Actual $caught.TargetObject -Message 'and the target the failure had, which is none'
Assert-Equal -Expected 'Gallery unreachable' -Actual $caught.Exception.Message -Message 'and the message of the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
$global:FakeInstallCalls.Clear()
Assert-Throws -ScriptBlock { $first, $second | Install-RequiredModule -ErrorAction Stop } `
    -MessageLike 'Gallery unreachable' `
    -Message 'Under -ErrorAction Stop a failed install still throws'
Assert-Equal -Expected @('Probe.First') -Actual @($global:FakeInstallCalls | ForEach-Object Name) `
    -Message 'and the next is not installed'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a name that is a pattern, and a name that is a parameter
$global:FakeInstallFailure = $null
$global:FakeInstallCalls.Clear()
$wildcard = [PSCustomObject]@{ Name = 'Az*'; MinimumVersion = [Version]'1.0.0' }
$option = [PSCustomObject]@{ Name = '-Force'; MinimumVersion = [Version]'1.0.0' }

# Act / Assert
Assert-Throws -ScriptBlock { Install-RequiredModule -Module $wildcard } `
    -MessageLike "*'Az*'*is not a valid module name*" `
    -Message 'A name with a wildcard in it is refused, as it would install every module it matches'
Assert-Throws -ScriptBlock { Install-RequiredModule -Module $option } `
    -MessageLike "*'-Force'*is not a valid module name*" `
    -Message 'and so is a name that starts with a dash'
Assert-Throws -ScriptBlock { Install-RequiredModule -Module 'Probe.First' } `
    -MessageLike 'A required module must be an object with a Name property*got String*' `
    -Message 'and the name of a module is not a module'
Assert-Equal -Expected 0 -Actual $global:FakeInstallCalls.Count -Message 'and nothing is installed for any of them'

# Cleanup
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
