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

$sandbox = New-RequiredModulesSandbox
Use-FakeInstaller -Module $module
$appear = {
    param($installing)
    New-FakeModule -Root $sandbox -Name $installing.Name -Version $installing.MinimumVersion.ToString()
}
$wanted = @{ 'Probe.Wanted' = @{ MinimumVersion = '1.0.0' } }
$mistaken = @{ 'Probe.Mistaken' = @{ Bogus = 'x' } }
$mistakenMessage = "RequiredModules entry 'Probe.Mistaken' has an unknown key 'Bogus' " +
    '(allowed: MinimumVersion, DocumentationUrl).'

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a manifest that needs an install, then one with a mistaken entry, piped in that order
    Use-AssertSeam -Module $module -OnInstall $appear

    # Act - the failing record comes before the end of the pipeline, where the installs happen
    $caught = $null
    try {
        $wanted, $mistaken | Assert-RequiredModule -ErrorAction $preference 6>$null
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected @() -Actual (Get-AssertSeamRecord -Module $module).Installs `
        -Message "Under -ErrorAction $preference a failing record stops the pipeline before anything is installed"
    Assert-Equal -Expected 'RuntimeException,Get-RequiredModule,Assert-RequiredModule' `
        -Actual $caught.FullyQualifiedErrorId -Message 'and the failure is still raised, as a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$caught = $null
try {
    $wanted, $mistaken | Assert-RequiredModule 6>$null
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Get-RequiredModule,Assert-RequiredModule' `
    -Actual $caught.FullyQualifiedErrorId `
    -Message 'A manifest that cannot be read raises a terminating error, whose ID names the failure and both commands'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with a category a caller can act on'
Assert-Equal -Expected $mistakenMessage -Actual $caught.TargetObject `
    -Message 'and the target the failure had, which is its message'
Assert-Equal -Expected $mistakenMessage -Actual $caught.Exception.Message -Message 'and the message of the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a manifest file that holds code and a secret
$secret = 'SENTINEL_SECRET_123'
$codePath = New-ManifestFile -Directory $sandbox -Name 'code.psd1' `
    -Content "@{ Pester = @{ MinimumVersion = (Get-Date) }; Secret = '$secret' }"
$unreadable = "*'$codePath' could not be read: it is not a PowerShell data file.*"

# Act
$caught = $null
try {
    Assert-RequiredModule -Path $codePath 6>$null
}
catch {
    $caught = $_
}

# Assert
Assert-That -Condition ($caught.Exception.Message -like $unreadable) `
    -Message 'A manifest file that holds code is refused, naming the file and the rule'
Assert-That -Condition (-not ($caught | Out-String).Contains($secret)) `
    -Message 'and nothing the failure shows holds the secret in the file'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two modules missing, and an install that fails
Use-AssertSeam -Module $module -RealInstall
$global:FakeInstallFailure = 'Gallery unreachable'
$twoMissing = @{
    'Probe.Alpha' = @{ MinimumVersion = '1.0.0' }
    'Probe.Bravo' = @{ MinimumVersion = '1.0.0' }
}
$installMessage = 'Could not install Probe.Alpha 1.0.0 or later: Gallery unreachable*'

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    $global:FakeInstallCalls.Clear()

    # Act
    $caught = $null
    try {
        Assert-RequiredModule -Data $twoMissing -ErrorAction $preference 6>$null
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected @('Probe.Alpha') -Actual @($global:FakeInstallCalls | ForEach-Object Name) `
        -Message "Under -ErrorAction $preference a failed install is not followed by the next one"
    Assert-Equal -Expected 'RuntimeException,Assert-RequiredModule' -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the failure is still raised, as a terminating error'
}

# Act
$caught = $null
try {
    Assert-RequiredModule -Data $twoMissing 6>$null
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Assert-RequiredModule' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A failed install raises a terminating error whose ID names the failure and the command'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with a category a caller can act on'
Assert-That -Condition ($caught.Exception.Message -like $installMessage) `
    -Message 'and the message of the failure, naming the module and the reason'
Assert-Equal -Expected $caught.Exception.Message -Actual $caught.TargetObject `
    -Message 'and the target the failure had, which is its message'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
$global:FakeInstallCalls.Clear()
Assert-Throws -ScriptBlock { Assert-RequiredModule -Data $twoMissing -ErrorAction Stop 6>$null } `
    -MessageLike $installMessage `
    -Message 'Under -ErrorAction Stop a failed install still throws'
Assert-Equal -Expected @('Probe.Alpha') -Actual @($global:FakeInstallCalls | ForEach-Object Name) `
    -Message 'and the next install is not tried'

# Cleanup
Remove-Module -Name 'Probe.*' -Force -ErrorAction Ignore
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
