#Requires -Version 7.4
using namespace System.Collections.Generic
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'RequiredModulesTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two manifests that read, and a path that names no manifest
$sandbox = New-RequiredModulesSandbox
$goodOne = New-ManifestFile -Directory $sandbox -Name 'one.psd1' `
    -Content "@{ 'Probe.One' = @{ MinimumVersion = '1.0.0' } }"
$goodTwo = New-ManifestFile -Directory $sandbox -Name 'two.psd1' `
    -Content "@{ 'Probe.Two' = @{ MinimumVersion = '1.0.0' } }"
$missing = Join-Path $sandbox 'missing.psd1'
$message = "RequiredModules manifest not found: $missing"

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    # Act - a failing call, whose caller asked for errors to be hidden
    $output = @()
    $caught = $null
    try {
        $output = @(Get-RequiredModule -Path $missing -ErrorAction $preference)
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $output.Count `
        -Message "Under -ErrorAction $preference a failing call returns nothing"
    Assert-Equal -Expected 'RuntimeException,Get-RequiredModule' -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the failure is still raised, as a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$caught = $null
try {
    $null = Get-RequiredModule -Path $missing
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Get-RequiredModule' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A manifest that is not there raises a terminating error whose ID names the failure and the command'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with a category a caller can act on'
Assert-Equal -Expected $message -Actual $caught.TargetObject `
    -Message 'and the target the failure had, which is its message'
Assert-Equal -Expected $message -Actual $caught.Exception.Message -Message 'and the message of the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
Assert-Throws -ScriptBlock { Get-RequiredModule -Path $missing -ErrorAction Stop } `
    -MessageLike '*manifest not found*' -Message 'Under -ErrorAction Stop a failing call still throws'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a good manifest, the failing path, and another good manifest, in that order
$read = [List[string]]::new()

# Act
$caught = $null
try {
    $records = foreach ($path in $goodOne, $missing, $goodTwo) {
        [PSCustomObject]@{ Path = $path }
    }

    $records | Get-RequiredModule | ForEach-Object { $read.Add($_.Name) }
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Get-RequiredModule' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A failing record in the pipeline raises the terminating error'
Assert-Equal -Expected @('Probe.One') -Actual $read.ToArray() `
    -Message 'the record before it is read, and the pipeline stops, so the record after it is not'

# Cleanup
Remove-RequiredModulesSandbox -Path $sandbox

exit (Complete-TestRun)
