#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/New-VSCodeStartInfo.ps1')

# Nothing is started here: each case only builds the start info and reads it.
$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
$tricky = '/tmp/my "odd" $HOME dir'
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    Push-Location -LiteralPath $root
    try {
        $info = New-VSCodeStartInfo -Executable 'C:\VS Code\Code.exe' -Argument @('--new-window', $tricky) `
            -OnWindows $true
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected 'C:\VS Code\Code.exe' -Actual $info.FileName `
        -Message 'On Windows the editor itself is started'
    Assert-Equal -Expected @('--new-window', $tricky) -Actual @($info.ArgumentList) `
        -Message 'with each argument its own item, as given'
    Assert-Equal -Expected $true -Actual $info.UseShellExecute `
        -Message 'through the shell, so it inherits none of this process''s handles'
    Assert-Equal -Expected $root -Actual $info.WorkingDirectory -Message 'in PowerShell''s current location'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    Push-Location -LiteralPath $root
    try {
        $info = New-VSCodeStartInfo -Executable '/usr/share/code/bin/code' -Argument @('--new-window', $tricky) `
            -OnWindows $false
    }
    finally {
        Pop-Location
    }

    # Assert
    $expected = @(
        '-c'
        'nohup "$0" "$@" </dev/null >/dev/null 2>&1 &'
        '/usr/share/code/bin/code'
        '--new-window'
        $tricky
    )
    Assert-Equal -Expected '/bin/sh' -Actual $info.FileName -Message 'Elsewhere sh is started'
    Assert-Equal -Expected $expected -Actual @($info.ArgumentList) `
        -Message 'with a fixed script, then the editor and each argument as items of their own, never spliced into the script'
    Assert-Equal -Expected $false -Actual $info.UseShellExecute -Message 'directly, not through a shell launcher'
    Assert-Equal -Expected $root -Actual $info.WorkingDirectory -Message 'in PowerShell''s current location too'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $info = New-VSCodeStartInfo -Executable 'code' -Argument @('x')

    # Assert
    Assert-Equal -Expected $IsWindows -Actual $info.UseShellExecute `
        -Message 'Without -OnWindows, this platform''s own form is built'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a location with no folder behind it
    Push-Location -LiteralPath 'Env:\'
    try {
        $info = New-VSCodeStartInfo -Executable 'code' -Argument @('x') -OnWindows $true
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected '' -Actual $info.WorkingDirectory `
        -Message 'Outside the file system, no working directory is set'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
