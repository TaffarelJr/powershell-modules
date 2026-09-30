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
# Arrange - two installed modules to update, and an updater that fails
$sandbox = New-RequiredModulesSandbox
Use-FakeInstaller -Module $module
New-FakeModule -Root $sandbox -Name 'Probe.First' -Version '1.0.0'
New-FakeModule -Root $sandbox -Name 'Probe.Second' -Version '1.0.0'
$global:FakeUpdateFailure = 'Gallery unreachable'
$first = [PSCustomObject]@{ Name = 'Probe.First'; MinimumVersion = [Version]'1.0.0' }
$second = [PSCustomObject]@{ Name = 'Probe.Second'; MinimumVersion = [Version]'1.0.0' }

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    $global:FakeUpdateCalls.Clear()

    # Act - a failing record, whose caller asked for errors to be hidden
    $caught = $null
    try {
        $first, $second | Update-RequiredModule -ErrorAction $preference
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected @('Probe.First') -Actual @($global:FakeUpdateCalls | ForEach-Object Name) `
        -Message "Under -ErrorAction $preference a failing record stops the pipeline, so the next is not updated"
    Assert-Equal `
        -Expected 'Microsoft.PowerShell.Commands.WriteErrorException,Update-Module,Update-RequiredModule' `
        -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the failure is still raised, as a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$global:FakeUpdateCalls.Clear()
$caught = $null
try {
    $first, $second | Update-RequiredModule
}
catch {
    $caught = $_
}

# Assert
Assert-Equal `
    -Expected 'Microsoft.PowerShell.Commands.WriteErrorException,Update-Module,Update-RequiredModule' `
    -Actual $caught.FullyQualifiedErrorId `
    -Message 'A failed update raises a terminating error whose ID names the failure and the commands'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with a category a caller can act on'
Assert-Equal -Expected 'Gallery unreachable' -Actual $caught.Exception.Message -Message 'and the message of the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
$global:FakeUpdateCalls.Clear()
Assert-Throws -ScriptBlock { $first, $second | Update-RequiredModule -ErrorAction Stop } `
    -MessageLike 'Gallery unreachable' `
    -Message 'Under -ErrorAction Stop a failed update still throws'
Assert-Equal -Expected @('Probe.First') -Actual @($global:FakeUpdateCalls | ForEach-Object Name) `
    -Message 'and the next is not updated'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a name that is a pattern, a name that is a parameter, and the name of a module as the module
$global:FakeUpdateFailure = $null
$global:FakeUpdateCalls.Clear()
$wildcard = [PSCustomObject]@{ Name = 'Az*'; MinimumVersion = [Version]'1.0.0' }
$option = [PSCustomObject]@{ Name = '-Force'; MinimumVersion = [Version]'1.0.0' }

# Act / Assert
Assert-Throws -ScriptBlock { Update-RequiredModule -Module $wildcard } `
    -MessageLike "*'Az*'*is not a valid module name*" `
    -Message 'A name with a wildcard in it is refused, as it would update every module it matches'
Assert-Throws -ScriptBlock { Update-RequiredModule -Module $option } `
    -MessageLike "*'-Force'*is not a valid module name*" `
    -Message 'and so is a name that starts with a dash'
Assert-Throws -ScriptBlock { Update-RequiredModule -Module 'Probe.First' } `
    -MessageLike 'A required module must be an object with a Name property*got String*' `
    -Message 'and the name of a module is not a module'
Assert-Equal -Expected 0 -Actual $global:FakeUpdateCalls.Count -Message 'and nothing is updated for any of them'

# Cleanup
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
