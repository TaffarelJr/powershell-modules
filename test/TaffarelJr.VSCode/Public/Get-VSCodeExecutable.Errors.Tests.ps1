#Requires -Version 7.4
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

$module = Get-Module TaffarelJr.VSCode
$sandbox = New-VSCodeSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an install folder that cannot be searched
    $null = Add-FakeVSCode -Fixture $sandbox
    & $module { function script:Get-VSCodeCandidate { throw 'The install folders could not be searched.' } }

    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        # Act - a failing search, whose caller asked for errors to be hidden
        $output = @()
        $caught = $null
        try {
            $output = @(Get-VSCodeExecutable -ErrorAction $preference)
        }
        catch {
            $caught = $_
        }

        # Assert
        Assert-Equal -Expected 0 -Actual $output.Count `
            -Message "Under -ErrorAction $preference a failing search finds nothing, not the install it skipped"
        Assert-Equal -Expected 'RuntimeException,Get-VSCodeExecutable' -Actual $caught.FullyQualifiedErrorId `
            -Message 'and the failure is still raised, as a terminating error'
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $caught = $null
    try {
        $null = Get-VSCodeExecutable
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,Get-VSCodeExecutable' -Actual $caught.FullyQualifiedErrorId `
        -Message 'A failing search raises a terminating error whose ID names the failure and the command'
    Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
        -Message 'with a category a caller can act on'
    Assert-Equal -Expected 'The install folders could not be searched.' -Actual $caught.TargetObject `
        -Message 'and the target the failure had, which is its message'
    Assert-Equal -Expected 'The install folders could not be searched.' -Actual $caught.Exception.Message `
        -Message 'and the message of the failure'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert
    Assert-Throws -ScriptBlock { Get-VSCodeExecutable -ErrorAction Stop } `
        -MessageLike 'The install folders could not be searched.' `
        -Message 'Under -ErrorAction Stop a failing search still throws'
}
finally {
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
