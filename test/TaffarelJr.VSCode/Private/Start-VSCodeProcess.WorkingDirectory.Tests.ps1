#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/New-VSCodeStartInfo.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Start-VSCodeProcess.ps1')
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

# A real, harmless program to launch: this very PowerShell, asked where it
# started.
$pwsh = (Get-Process -Id $PID).Path
$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
$elsewhere = Join-Path $root 'elsewhere'
New-Item -ItemType Directory -Path $elsewhere | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a PowerShell location that is not the host process's own
    $report = Join-Path $root 'where.txt'
    $script = Join-Path $root 'where.ps1'
    [File]::WriteAllText($script, 'Set-Content -LiteralPath $args[0] -Value ([Environment]::CurrentDirectory)')

    # Act
    Push-Location -LiteralPath $elsewhere
    try {
        $here = (Get-Location).ProviderPath
        Start-VSCodeProcess -Executable $pwsh -Argument @('-NoProfile', '-NoLogo', '-File', $script, $report)
    }
    finally {
        Pop-Location
    }

    $arrived = Wait-TestFile -Path $report

    # Assert
    Assert-That -Condition $arrived -Message 'The launched process ran'
    Assert-Equal -Expected $here -Actual ([File]::ReadAllText($report).Trim()) `
        -Message 'The process starts where PowerShell is, not where the host process began'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
