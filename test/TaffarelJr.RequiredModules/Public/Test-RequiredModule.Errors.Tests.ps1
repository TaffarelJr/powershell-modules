#Requires -Version 7.4
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a module that is installed, and an object that is not a module requirement
$sandbox = New-RequiredModulesSandbox
New-FakeModule -Root $sandbox -Name 'Probe.Present' -Version '2.0.0'
$present = [PSCustomObject]@{ Name = 'Probe.Present'; MinimumVersion = [Version]'1.0.0' }
$nameless = [PSCustomObject]@{ MinimumVersion = [Version]'1.0.0' }

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    # Act - a failing call, whose caller asked for errors to be hidden
    $output = @()
    $caught = $null
    try {
        $output = @(Test-RequiredModule -Module $nameless -ErrorAction $preference)
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $output.Count `
        -Message "Under -ErrorAction $preference a failing call answers nothing"
    Assert-Equal -Expected 'RuntimeException,Test-RequiredModule' -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the failure is still raised, as a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$caught = $null
try {
    $null = Test-RequiredModule -Module $nameless
}
catch {
    $caught = $_
}

# Assert
$message = 'A required module must be an object with a Name property, as Get-RequiredModule returns one; ' +
'got PSCustomObject.'
Assert-Equal -Expected 'RuntimeException,Test-RequiredModule' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A failing call raises a terminating error that keeps the ID of the failure and names the command'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with its category'
Assert-Equal -Expected $message -Actual $caught.TargetObject `
    -Message 'and the target the failure had, which is its message'
Assert-Equal -Expected $message -Actual $caught.Exception.Message -Message 'and the message of the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
Assert-Throws -ScriptBlock { Test-RequiredModule -Module $nameless -ErrorAction Stop } `
    -MessageLike 'A required module must be an object with a Name property*' `
    -Message 'Under -ErrorAction Stop a failing call still throws'

#───────────────────────────────────────────────────────────────────────────────
# Act - an answer, the failing record, and an answer that is never given
$answers = [System.Collections.Generic.List[bool]]::new()
$caught = $null
try {
    $present, $nameless, $present | Test-RequiredModule | ForEach-Object { $answers.Add($_) }
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Test-RequiredModule' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A failing record in the pipeline raises the terminating error'
Assert-Equal -Expected @($true) -Actual $answers.ToArray() `
    -Message 'the record before it is answered, and the pipeline stops, so the record after it is not'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - things that are not a required module at all, and a name that is not a module's
Assert-Throws -ScriptBlock { Test-RequiredModule -Module 'Pester' } `
    -MessageLike 'A required module must be an object with a Name property*got String*' `
    -Message 'The name of a module is refused, saying what an object is expected'
Assert-Throws -ScriptBlock { Test-RequiredModule -Module ([PSCustomObject]@{ Name = 'Probe*' }) } `
    -MessageLike "*'Probe*'*is not a valid module name*" `
    -Message 'and so is a name with a wildcard in it, which would match other modules'

# Cleanup
Remove-Module -Name 'Probe.*' -Force -ErrorAction Ignore
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
