#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/New-VSCodeStartInfo.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Start-VSCodeProcess.ps1')
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'the registry drive that has a path no process can start in exists on Windows only')
}

# The registry drive is a location whose "provider path" names no folder, and
# a process cannot start in it.
$pwsh = (Get-Process -Id $PID).Path
$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $report = Join-Path $root 'ran.txt'
    $script = Join-Path $root 'ran.ps1'
    [File]::WriteAllText($script, 'Set-Content -LiteralPath $args[0] -Value ran')

    # Act
    Push-Location -LiteralPath 'HKCU:\'
    try {
        Start-VSCodeProcess -Executable $pwsh -Argument @('-NoProfile', '-NoLogo', '-File', $script, $report)
    }
    finally {
        Pop-Location
    }

    $arrived = Wait-TestFile -Path $report

    # Assert
    Assert-That -Condition $arrived `
        -Message 'The process still starts when PowerShell is in the registry, which is no folder to start it in'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
