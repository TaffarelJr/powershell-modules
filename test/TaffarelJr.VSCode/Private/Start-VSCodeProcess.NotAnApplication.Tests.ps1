#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/New-VSCodeStartInfo.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Start-VSCodeProcess.ps1')

# Elsewhere sh starts the editor in the background, so the start itself
# never fails once the file is there.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'only a Windows start fails inside the launch itself')
}

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
$originalElectronMode = $env:ELECTRON_RUN_AS_NODE
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an empty Code.exe, which exists but is no program, started by
    # a caller inside VS Code's own extension host
    $empty = Join-Path $root 'Code.exe'
    [File]::WriteAllText($empty, '')
    $env:ELECTRON_RUN_AS_NODE = '1'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-VSCodeProcess -Executable $empty -Argument @('x')
    } -ExceptionType ([ComponentModel.Win32Exception]) -MessageLike "*$([WildcardPattern]::Escape($empty))*" `
        -Message 'A start Windows refuses for another reason throws its own error, naming the file'
    Assert-Equal -Expected '1' -Actual $env:ELECTRON_RUN_AS_NODE `
        -Message 'and ELECTRON_RUN_AS_NODE is put back for the caller after the failed start'
}
finally {
    [Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $originalElectronMode, 'Process')
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
