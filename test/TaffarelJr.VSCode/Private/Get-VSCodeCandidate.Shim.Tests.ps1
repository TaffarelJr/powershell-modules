#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.FileText/TaffarelJr.FileText.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.VSCode/TaffarelJr.VSCode.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

# The CLI shim is a code.cmd, found through PATHEXT - a shape only Windows has.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'the CLI shim is a Windows .cmd')
}

$stable = @(Get-VSCodeEditionTable)[0]
$originalPathExt = $env:PATHEXT
$sandbox = New-VSCodeSandbox
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an install laid out as VS Code's own is: bin\code.cmd beside
    # the executable's folder
    $install = Add-FakeVSCodeShim -Fixture $sandbox

    # Act
    $candidates = @(& $module { param($e) Get-VSCodeCandidate -Edition $e } $stable)

    # Assert
    $expected = @(
        (Join-Path $install.InstallRoot $stable.Exe)
        $install.Shim
        (Join-Path $sandbox.LocalAppData 'Programs' $stable.Folder $stable.Exe)
        (Join-Path $sandbox.ProgramFiles $stable.Folder $stable.Exe)
    )
    Assert-Equal -Expected $expected -Actual $candidates `
        -Message 'The executable beside the shim''s folder comes first, then the shim, then the install folders'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - only the extensionless bin\code, VS Code's script for a Unix
    # shell, which Windows cannot start
    $install = Add-FakeVSCodeShim -Fixture $sandbox -FileName 'code'

    # Act
    $candidates = @(& $module { param($e) Get-VSCodeCandidate -Edition $e } $stable)

    # Assert
    $expected = @(
        (Join-Path $sandbox.LocalAppData 'Programs' $stable.Folder $stable.Exe)
        (Join-Path $sandbox.ProgramFiles $stable.Folder $stable.Exe)
    )
    Assert-Equal -Expected $expected -Actual $candidates `
        -Message 'A shim whose extension is not in PATHEXT adds no candidate'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same, with a trailing ';' in PATHEXT, which splits off an
    # empty entry
    $env:PATHEXT = "$originalPathExt;"

    # Act
    $candidates = @(& $module { param($e) Get-VSCodeCandidate -Edition $e } $stable)
    $env:PATHEXT = $originalPathExt

    # Assert
    Assert-Equal -Expected $expected -Actual $candidates `
        -Message 'An empty PATHEXT entry does not let the extensionless script in'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a stray extensionless code earlier on PATH than a real install
    $stray = Add-FakeVSCodeShim -Fixture $sandbox -FileName 'code'
    $install = Add-FakeVSCodeShim -Fixture $sandbox
    $env:PATH = (Split-Path -Parent $stray.Shim), (Split-Path -Parent $install.Shim) -join [Path]::PathSeparator

    # Act
    $candidates = @(& $module { param($e) Get-VSCodeCandidate -Edition $e } $stable)

    # Assert
    $expected = @(
        (Join-Path $install.InstallRoot $stable.Exe)
        $install.Shim
        (Join-Path $sandbox.LocalAppData 'Programs' $stable.Folder $stable.Exe)
        (Join-Path $sandbox.ProgramFiles $stable.Folder $stable.Exe)
    )
    Assert-Equal -Expected $expected -Actual $candidates `
        -Message 'The executable is worked out from the first shim Windows can start, not the first code on PATH'
}
finally {
    $env:PATHEXT = $originalPathExt
    Remove-VSCodeSandbox -Fixture $sandbox
}

exit (Complete-TestRun)
