#Requires -Version 7.4
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
    $launches = @(Get-FakeVSCodeLaunch -Module $module)

    # Assert
    Assert-Equal -Expected 1 -Actual $launches.Count -Message 'One call makes one launch'
    Assert-Equal -Expected $stable -Actual $launches[0].Executable -Message 'The installed executable is launched'
    Assert-Equal -Expected @($repo) -Actual $launches[0].Argument -Message 'The path is the only argument'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Start-VSCode -Path $repo, $other
    $launches = @(Get-FakeVSCodeLaunch -Module $module)

    # Assert
    Assert-Equal -Expected 1 -Actual $launches.Count -Message 'Several paths still make one launch'
    Assert-Equal -Expected @($repo, $other) -Actual $launches[0].Argument -Message 'The paths keep the order given'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Start-VSCode -Path $repo -Window New
    $launches = @(Get-FakeVSCodeLaunch -Module $module)

    # Assert
    Assert-Equal -Expected @('--new-window', $repo) -Actual $launches[0].Argument `
        -Message '-Window New puts --new-window ahead of the path'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Start-VSCode -Path $repo -Window Reuse
    $launches = @(Get-FakeVSCodeLaunch -Module $module)

    # Assert
    Assert-Equal -Expected @('--reuse-window', $repo) -Actual $launches[0].Argument `
        -Message '-Window Reuse puts --reuse-window ahead of the path'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a relative path, from a different current location than the
    # process's own, which is where a launched editor would otherwise look
    Install-FakeVSCodeLauncher -Module $module
    Push-Location (Join-Path $sandbox.Root 'work')

    # Act
    Start-VSCode -Path 'repo'
    Pop-Location
    $launches = @(Get-FakeVSCodeLaunch -Module $module)

    # Assert
    Assert-Equal -Expected @($repo) -Actual $launches[0].Argument `
        -Message 'A relative path is resolved against the current location'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act
    $repo, $other | Start-VSCode
    $launches = @(Get-FakeVSCodeLaunch -Module $module)

    # Assert
    Assert-Equal -Expected 1 -Actual $launches.Count -Message 'Piped strings are opened by one launch'
    Assert-Equal -Expected @($repo, $other) -Actual $launches[0].Argument `
        -Message 'Every piped string is opened, in order'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Get-Item -LiteralPath $repo, $other | Start-VSCode
    $launches = @(Get-FakeVSCodeLaunch -Module $module)

    # Assert
    Assert-Equal -Expected 1 -Actual $launches.Count -Message 'Piped directories are opened by one launch'
    Assert-Equal -Expected @($repo, $other) -Actual $launches[0].Argument `
        -Message 'A piped directory is opened by its FullName'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an object that carries its path in a Path property
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Resolve-Path -LiteralPath $repo | Start-VSCode
    $launches = @(Get-FakeVSCodeLaunch -Module $module)

    # Assert
    Assert-Equal -Expected @($repo) -Actual $launches[0].Argument -Message 'A piped object is opened by its Path'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - dictionaries carrying the path, in any casing, including one
    # whose own lookup is case-sensitive
    Install-FakeVSCodeLauncher -Module $module
    $exact = [System.Collections.Generic.Dictionary[string, object]]::new()
    $exact['path'] = $repo

    # Act
    @{ FullName = $other }, $exact | Start-VSCode
    $launches = @(Get-FakeVSCodeLaunch -Module $module)

    # Assert
    Assert-Equal -Expected @($other, $repo) -Actual $launches[0].Argument `
        -Message 'A dictionary is opened by its Path or FullName entry, in any casing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a dictionary keyed by numbers, which cannot hold a Path
    Install-FakeVSCodeLauncher -Module $module
    $numbered = [System.Collections.Generic.Dictionary[int, object]]::new()
    $numbered[1] = $repo

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-VSCode -Path $numbered
    } -MessageLike '*no Path or FullName*' `
        -Message 'A dictionary with keys that are not strings is refused with the module''s own message'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - blank paths, which would otherwise open the current folder
    Install-FakeVSCodeLauncher -Module $module
    $blank = @(
        @{ Path = @(''); Message = 'An empty path is refused' }
        @{ Path = @('   '); Message = 'A path of only whitespace is refused' }
        @{ Path = @($repo, ''); Message = 'An empty path among others is refused' }
        @{ Path = @([PSCustomObject]@{ Path = '  ' }); Message = 'An object whose Path is only whitespace is refused' }
    )

    # Act / Assert
    foreach ($case in $blank) {
        Assert-Throws -ScriptBlock {
            Start-VSCode -Path $case.Path
        } -MessageLike '*-Path is empty or only whitespace*' -Message $case.Message
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeVSCodeLaunch -Module $module).Count `
        -Message 'and none of them launches anything'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Install-FakeVSCodeLauncher -Module $module

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-VSCode -Path 'Q9:\x'
    } -MessageLike "*Cannot open 'Q9:\x' in VS Code*Q9*" `
        -Message 'A path on a drive that does not exist is refused with the module''s own message'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an object with neither Path nor FullName
    Install-FakeVSCodeLauncher -Module $module
    $issue = [PSCustomObject]@{
        Number = 7
        Title  = 'x'
    }

    # Act / Assert
    Assert-Throws -ScriptBlock {
        $issue | Start-VSCode
    } -MessageLike '*no Path or FullName*' `
        -Message 'A piped object with no path in it is refused, not opened as its text'
    Assert-Equal -Expected 0 -Actual @(Get-FakeVSCodeLaunch -Module $module).Count -Message 'and nothing is launched'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - places that are not in the file system
    Install-FakeVSCodeLauncher -Module $module

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-VSCode -Path 'Env:\PATH'
    } -MessageLike '*file system*Environment*Env:\PATH*' `
        -Message 'A path in another provider is refused, naming the provider'

    # Act
    Push-Location -LiteralPath 'Env:\'

    # Assert
    try {
        Assert-Throws -ScriptBlock {
            Start-VSCode -Path 'repo'
        } -MessageLike '*file system*Environment*' `
            -Message 'A relative path is refused while PowerShell is in another provider'
    }
    finally {
        Pop-Location
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeVSCodeLaunch -Module $module).Count `
        -Message 'and neither launches anything'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - both editions installed
    $insiders = Add-FakeVSCode -Fixture $sandbox -Edition Insiders
    Install-FakeVSCodeLauncher -Module $module

    # Act
    Start-VSCode -Path $repo -Edition Insiders
    $launches = @(Get-FakeVSCodeLaunch -Module $module)

    # Assert
    Assert-Equal -Expected $insiders -Actual $launches[0].Executable `
        -Message '-Edition Insiders launches Insiders even with Stable installed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - nothing installed
    Reset-VSCodeSandbox -Fixture $sandbox
    Install-FakeVSCodeLauncher -Module $module

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-VSCode -Path $repo
    } -MessageLike '*VS Code was not found*' -Message 'With no install, the error says VS Code was not found'
    Assert-Throws -ScriptBlock {
        Start-VSCode -Path $repo -Edition Stable
    } -MessageLike '*VS Code (Stable) was not found*' -Message 'With -Edition, the error names the edition looked for'
    Assert-Equal -Expected 0 -Actual @(Get-FakeVSCodeLaunch -Module $module).Count `
        -Message 'Nothing is launched when VS Code is not found'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an install, but a launch that fails
    $null = Add-FakeVSCode -Fixture $sandbox
    Install-FakeVSCodeLauncher -Module $module -Throw

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-VSCode -Path $repo
    } -MessageLike 'Could not launch VS Code: the launch failed' `
        -Message 'A failed launch is reported with its own reason, not wrapped in parentheses'
}
finally {
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
