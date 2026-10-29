#Requires -Version 7.4
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module that can be imported, and one that is nowhere on PSModulePath
$sandbox = New-RequiredModulesSandbox
New-FakeModule -Root $sandbox -Name 'Probe.Importable' -Version '1.0.0'
$importable = [PSCustomObject]@{ Name = 'Probe.Importable'; MinimumVersion = [Version]'1.0.0' }
$absent = [PSCustomObject]@{ Name = 'Probe.Absent'; MinimumVersion = [Version]'1.0.0' }
$absentMessage = "The specified module 'Probe.Absent' with version '1.0.0' was not loaded because no valid " +
    'module file was found in any module directory.'
$failureId = 'Modules_ModuleWithVersionNotFound,Microsoft.PowerShell.Commands.ImportModuleCommand,' +
    'Import-RequiredModule'

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    # Act - a failing call, whose caller asked for errors to be hidden
    $caught = $null
    try {
        Import-RequiredModule -Module $absent -ErrorAction $preference
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected $failureId -Actual $caught.FullyQualifiedErrorId `
        -Message "Under -ErrorAction $preference an import that fails is still raised, as a terminating error"
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$caught = $null
try {
    Import-RequiredModule -Module $absent
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected $failureId -Actual $caught.FullyQualifiedErrorId `
    -Message 'A module that cannot be imported raises a terminating error that keeps the ID of the failure'
Assert-Equal -Expected ([ErrorCategory]::ResourceUnavailable) -Actual $caught.CategoryInfo.Category `
    -Message 'and its category'
Assert-Equal -Expected 'Probe.Absent' -Actual $caught.TargetObject -Message 'and its target, the module'
Assert-Equal -Expected $absentMessage -Actual $caught.Exception.Message -Message 'and the message of the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
Assert-Throws -ScriptBlock { Import-RequiredModule -Module $absent -ErrorAction Stop } `
    -MessageLike '*Probe.Absent*was not loaded*' -Message 'Under -ErrorAction Stop it still throws'

#───────────────────────────────────────────────────────────────────────────────
# Act - the failing module first, then one that would import
$caught = $null
try {
    $absent, $importable | Import-RequiredModule
}
catch {
    $caught = $_
}
$loaded = @(Get-Module -Name 'Probe.Importable')

# Assert
Assert-Equal -Expected $failureId -Actual $caught.FullyQualifiedErrorId `
    -Message 'A failing record in the pipeline raises the terminating error'
Assert-Equal -Expected 0 -Actual $loaded.Count `
    -Message 'and the pipeline stops, so the record after it is not imported'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - a name that is a pattern, and the name of a module given as the module
Assert-Throws -ScriptBlock { Import-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe.*' }) } `
    -MessageLike "*'Probe.*'*is not a valid module name*" `
    -Message 'A name with a wildcard in it is refused, as it would import every module it matches'
Assert-Throws -ScriptBlock { Import-RequiredModule -Module 'Probe.Importable' } `
    -MessageLike 'A required module must be an object with a Name property*got String*' `
    -Message 'and the name of a module is not a module'

# Cleanup
Remove-Module -Name 'Probe.*' -Force -ErrorAction Ignore
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
