#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Private/Find-NativeCommand.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Private/Invoke-NativeProcess.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Public/Hide-UrlCredential.ps1')

# What the platform raises for a file that exists but cannot be run differs;
# the Windows loader error is the one this case pins down.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'the failure being checked is a Windows loader error')
}

# Windows shows a dialog that waits for a click when a file that is not a
# program is started, so this runs only when asked for.
if ($env:TAFFARELJR_TEST_BROKEN_EXE -ne '1') {
    exit (Skip-TestRun -Reason 'starting a broken .exe opens a Windows dialog; set TAFFARELJR_TEST_BROKEN_EXE=1')
}

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file that is not a program, under an executable's name
    $junk = Join-Path $root 'not-a-program.exe'
    [File]::WriteAllText($junk, 'this is not an executable')

    # Act
    $result = Invoke-NativeProcess -Command $junk -Arguments @('x')

    # Assert
    Assert-That -Condition (-not $result.Started) `
        -Message 'A file that cannot be run is reported as not started, not thrown'
    Assert-Equal -Expected 127 -Actual $result.ExitCode `
        -Message 'It gets the same "could not start" code as a missing command'
    Assert-That -Condition ($result.Output[0] -match '\S') -Message 'and a reason, rather than nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same file, in a folder named like a credential
    $folder = Join-Path $root 'SENTINEL@h.example'
    New-Item -ItemType Directory -Path $folder | Out-Null
    $hiddenJunk = Join-Path $folder 'not-a-program.exe'
    [File]::WriteAllText($hiddenJunk, 'this is not an executable')

    # Act
    $hidden = Invoke-NativeProcess -Command $hiddenJunk -Arguments @('x')

    # Assert
    Assert-Equal -Expected $false -Actual ($hidden.Output[0] -like '*SENTINEL*') `
        -Message 'The reason the platform gives hides a credential in the path it names'
    Assert-Equal -Expected $true -Actual ($hidden.Output[0] -like '`*`*`*@h.example\not-a-program.exe*') `
        -Message 'and keeps the rest of it'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
