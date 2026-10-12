#Requires -Version 7.0
using namespace System.IO

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
    # Arrange - a Stable install, and a launcher that records
    $stable = Add-FakeVSCode -Fixture $sandbox
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Start-VSCode -Path $repo
    $launches = Get-FakeVSCodeLaunch -Module $module

    # Assert
    Assert-Equal -Expected 1 -Actual $launches.Count -Message 'One call makes one launch'
    Assert-Equal -Expected $stable -Actual $launches[0].Executable -Message 'The installed executable is launched'
    Assert-Equal -Expected @($repo) -Actual $launches[0].Argument -Message 'The path is the only argument'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Start-VSCode -Path $repo, $other
    $launches = Get-FakeVSCodeLaunch -Module $module

    # Assert
    Assert-Equal -Expected 1 -Actual $launches.Count -Message 'Several paths still make one launch'
    Assert-Equal -Expected @($repo, $other) -Actual $launches[0].Argument -Message 'The paths keep the order given'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Start-VSCode -Path $repo -Window New
    $launches = Get-FakeVSCodeLaunch -Module $module

    # Assert
    Assert-Equal -Expected @('--new-window', $repo) -Actual $launches[0].Argument -Message '-Window New puts --new-window ahead of the path'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Start-VSCode -Path $repo -Window Reuse
    $launches = Get-FakeVSCodeLaunch -Module $module

    # Assert
    Assert-Equal -Expected @('--reuse-window', $repo) -Actual $launches[0].Argument -Message '-Window Reuse puts --reuse-window ahead of the path'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a relative path, from a different current location than the
    # process's own, which is where a launched editor would otherwise look
    Install-FakeVSCodeLauncher -Module $module
    Push-Location (Join-Path $sandbox.Root 'work')

    # Act
    Start-VSCode -Path 'repo'
    Pop-Location
    $launches = Get-FakeVSCodeLaunch -Module $module

    # Assert
    Assert-Equal -Expected @($repo) -Actual $launches[0].Argument -Message 'A relative path is resolved against the current location'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act
    $repo, $other | Start-VSCode
    $launches = Get-FakeVSCodeLaunch -Module $module

    # Assert
    Assert-Equal -Expected 1 -Actual $launches.Count -Message 'Piped strings are opened by one launch'
    Assert-Equal -Expected @($repo, $other) -Actual $launches[0].Argument -Message 'Every piped string is opened, in order'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Get-Item -LiteralPath $repo, $other | Start-VSCode
    $launches = Get-FakeVSCodeLaunch -Module $module

    # Assert
    Assert-Equal -Expected 1 -Actual $launches.Count -Message 'Piped directories are opened by one launch'
    Assert-Equal -Expected @($repo, $other) -Actual $launches[0].Argument -Message 'A piped directory is opened by its FullName'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - both editions installed
    $insiders = Add-FakeVSCode -Fixture $sandbox -Edition Insiders
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Start-VSCode -Path $repo -Edition Insiders
    $launches = Get-FakeVSCodeLaunch -Module $module

    # Assert
    Assert-Equal -Expected $insiders -Actual $launches[0].Executable -Message '-Edition Insiders launches Insiders even with Stable installed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - nothing installed
    Reset-VSCodeSandbox -Fixture $sandbox
    Install-FakeVSCodeLauncher -Module $module

    # Act
    $message = Get-ErrorMessage -ScriptBlock { Start-VSCode -Path $repo }
    $launches = Get-FakeVSCodeLaunch -Module $module

    # Assert
    Assert-That -Condition ($message -like '*VS Code was not found*') -Message 'With no install, the error says VS Code was not found'
    Assert-Equal -Expected 0 -Actual $launches.Count -Message 'Nothing is launched when VS Code is not found'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an install, but a launch that fails
    $null = Add-FakeVSCode -Fixture $sandbox
    Install-FakeVSCodeLauncher -Module $module -Throw

    # Act
    $message = Get-ErrorMessage -ScriptBlock { Start-VSCode -Path $repo }

    # Assert
    Assert-That -Condition ($message -like '*Could not launch VS Code*the launch failed*') -Message 'A failed launch is reported with its own reason'
}
finally {
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
