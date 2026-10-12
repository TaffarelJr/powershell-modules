#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Start-VSCodeProcess.ps1')
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

# A real, harmless program to launch: this very PowerShell.
$pwsh = (Get-Process -Id $PID).Path
$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act
    $result = Start-VSCodeProcess -Executable $pwsh -Argument @('-NoProfile', '-NoLogo', '-Command', 'exit 0')

    # Assert
    Assert-That -Condition ($null -eq $result) -Message 'A launched process hands nothing back'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a child that reports the arguments it actually received
    $script = Join-Path $root 'report.ps1'
    $report = Join-Path $root 'report.txt'
    [File]::WriteAllText($script, '$out, $rest = $args; Set-Content -LiteralPath $out -Value ($rest.Count.ToString() + "|" + ($rest -join "|"))')

    # Act
    Start-VSCodeProcess -Executable $pwsh -Argument @('-NoProfile', '-NoLogo', '-File', $script, $report, 'a folder\with spaces', 'plain')
    $arrived = Wait-TestFile -Path $report

    # Assert
    Assert-That -Condition $arrived -Message 'The launched process ran'
    Assert-Equal -Expected '2|a folder\with spaces|plain' -Actual ([File]::ReadAllText($report).Trim()) -Message 'An argument containing spaces reaches the process as one argument'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Start-VSCodeProcess -Executable (Join-Path $root 'no-such-program') -Argument @('x') } -Message 'An executable that does not exist throws'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
