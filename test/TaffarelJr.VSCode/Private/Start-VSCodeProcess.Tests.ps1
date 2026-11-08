#Requires -Version 7.4
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/New-VSCodeStartInfo.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.VSCode/Private/Start-VSCodeProcess.ps1')
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

# A real, harmless program to launch: this very PowerShell.
$pwsh = (Get-Process -Id $PID).Path
$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
$originalElectronMode = $env:ELECTRON_RUN_AS_NODE
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
    $arguments = @('-NoProfile', '-NoLogo', '-File', $script, $report, 'a folder\with spaces', 'plain')
    Start-VSCodeProcess -Executable $pwsh -Argument $arguments
    $arrived = Wait-TestFile -Path $report

    # Assert
    Assert-That -Condition $arrived -Message 'The launched process ran'
    Assert-Equal -Expected '2|a folder\with spaces|plain' -Actual ([File]::ReadAllText($report).Trim()) `
        -Message 'An argument containing spaces reaches the process as one argument'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a caller inside VS Code's own extension host, which sets this
    # and so would make the editor run as plain Node
    $script = Join-Path $root 'electron.ps1'
    $report = Join-Path $root 'electron.txt'
    [File]::WriteAllText($script, 'Set-Content -LiteralPath $args[0] -Value "[$env:ELECTRON_RUN_AS_NODE]"')
    $env:ELECTRON_RUN_AS_NODE = '1'

    # Act
    Start-VSCodeProcess -Executable $pwsh -Argument @('-NoProfile', '-NoLogo', '-File', $script, $report)
    $callerValue = $env:ELECTRON_RUN_AS_NODE
    $arrived = Wait-TestFile -Path $report

    # Assert
    Assert-That -Condition $arrived -Message 'The launched process ran'
    Assert-Equal -Expected '[]' -Actual ([File]::ReadAllText($report).Trim()) `
        -Message 'ELECTRON_RUN_AS_NODE is not passed on to the launched process'
    Assert-Equal -Expected '1' -Actual $callerValue -Message 'and is put back for the caller afterwards'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    [Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $null, 'Process')

    # Act
    Start-VSCodeProcess -Executable $pwsh -Argument @('-NoProfile', '-NoLogo', '-Command', 'exit 0')

    # Assert
    Assert-That -Condition (-not (Test-Path -LiteralPath 'Env:\ELECTRON_RUN_AS_NODE')) `
        -Message 'ELECTRON_RUN_AS_NODE is not created for a caller that never had it'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Start-VSCodeProcess -Executable (Join-Path $root 'no-such-program') -Argument @('x')
    } -MessageLike '*executable does not exist*no-such-program*' `
        -Message 'An executable that does not exist is refused before anything starts, naming it'
}
finally {
    [Environment]::SetEnvironmentVariable('ELECTRON_RUN_AS_NODE', $originalElectronMode, 'Process')
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
