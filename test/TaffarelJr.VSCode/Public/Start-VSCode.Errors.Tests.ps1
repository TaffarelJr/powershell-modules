#Requires -Version 7.4
using namespace System.IO
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
$repo = Join-Path $sandbox.Root 'work' 'repo'
$other = Join-Path $sandbox.Root 'work' 'other'
New-Item -ItemType Directory -Path $repo, $other | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an install and a launcher that records, and a path that is only whitespace
    $null = Add-FakeVSCode -Fixture $sandbox
    $blankMessage = '-Path is empty or only whitespace. Give a folder, workspace, or file to open.'

    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        Install-FakeVSCodeLauncher -Module $module

        # Act - a failing record in the pipeline, whose caller asked for errors to be hidden
        $caught = $null
        try {
            $repo, ' ', $other | Start-VSCode -ErrorAction $preference
        }
        catch {
            $caught = $_
        }

        # Assert
        Assert-Equal -Expected @() -Actual @(Get-FakeVSCodeLaunch -Module $module) `
            -Message "Under -ErrorAction $preference a failing record stops the pipeline before anything is launched"
        Assert-Equal -Expected 'RuntimeException,Start-VSCode' -Actual $caught.FullyQualifiedErrorId `
            -Message 'and the failure is still raised, as a terminating error'
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act
    $caught = $null
    try {
        Start-VSCode -Path ' '
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,Start-VSCode' -Actual $caught.FullyQualifiedErrorId `
        -Message 'A path that is refused raises a terminating error whose ID names the failure and the command'
    Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
        -Message 'with a category a caller can act on'
    Assert-Equal -Expected $blankMessage -Actual $caught.TargetObject `
        -Message 'and the target the failure had, which is its message'
    Assert-Equal -Expected $blankMessage -Actual $caught.Exception.Message -Message 'and the message of the failure'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert
    Assert-Throws -ScriptBlock { $repo, ' ' | Start-VSCode -ErrorAction Stop } `
        -MessageLike '*empty or only whitespace*' `
        -Message 'Under -ErrorAction Stop a path that is refused still throws'
    Assert-Equal -Expected @() -Actual @(Get-FakeVSCodeLaunch -Module $module) -Message 'and nothing is launched'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - nothing installed
    Reset-VSCodeSandbox -Fixture $sandbox
    Install-FakeVSCodeLauncher -Module $module

    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        # Act
        $caught = $null
        try {
            Start-VSCode -Path $repo -ErrorAction $preference
        }
        catch {
            $caught = $_
        }

        # Assert
        Assert-Equal -Expected @() -Actual @(Get-FakeVSCodeLaunch -Module $module) `
            -Message "Under -ErrorAction $preference an editor that is not found is not launched"
        Assert-Equal -Expected 'RuntimeException,Start-VSCode' -Actual $caught.FullyQualifiedErrorId `
            -Message 'and the failure is still raised, as a terminating error'
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an install, but a launch that fails
    $null = Add-FakeVSCode -Fixture $sandbox
    Install-FakeVSCodeLauncher -Module $module -Throw

    # Act
    $caught = $null
    try {
        Start-VSCode -Path $repo -ErrorAction SilentlyContinue
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,Start-VSCode' -Actual $caught.FullyQualifiedErrorId `
        -Message 'A launch that fails is raised as a terminating error, even with errors hidden'
    Assert-Equal -Expected 'Could not launch VS Code: the launch failed' -Actual $caught.Exception.Message `
        -Message 'with its own reason'
}
finally {
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
