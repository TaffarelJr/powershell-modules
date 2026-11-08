#Requires -Version 7.4
using namespace System.Diagnostics
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'VSCodeTestHelper.ps1')

# What keeps the caller's output pipe open is Windows' handle inheritance;
# the launch that avoids it there is not the one used elsewhere.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'the inherited output handle this guards against is a Windows launch detail')
}

# A caller whose output is being captured - a CI step, or $out = pwsh -File
# ... - launches a long-lived stand-in editor (this very PowerShell, asleep)
# and exits. Reading the caller's output to the end must not wait for the
# stand-in to close.
$pwsh = (Get-Process -Id $PID).Path
$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
$caller = $null
$standInFile = Join-Path $root 'stand-in.pid'
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $callerScript = Join-Path $root 'caller.ps1'
    $callerCode = @'
param($Repo, $Pwsh, $PidFile)
$ErrorActionPreference = 'Stop'
. (Join-Path $Repo 'src/TaffarelJr.VSCode/Private/New-VSCodeStartInfo.ps1')
. (Join-Path $Repo 'src/TaffarelJr.VSCode/Private/Start-VSCodeProcess.ps1')
$editor = "Set-Content -LiteralPath '$PidFile' -Value `$PID; Start-Sleep -Seconds 120"
Start-VSCodeProcess -Executable $Pwsh -Argument @('-NoProfile', '-NoLogo', '-WindowStyle', 'Hidden', '-Command', $editor)
'launched'
'@
    [File]::WriteAllText($callerScript, $callerCode)
    $info = [ProcessStartInfo]::new($pwsh)
    foreach ($item in '-NoProfile', '-NoLogo', '-File', $callerScript, $repoRoot, $pwsh, $standInFile) {
        $info.ArgumentList.Add($item)
    }

    $info.RedirectStandardOutput = $true
    $info.UseShellExecute = $false

    # Act
    $caller = [Process]::Start($info)
    $read = $caller.StandardOutput.ReadToEndAsync()
    $finished = $read.Wait(60000)
    $standInStarted = Wait-TestFile -Path $standInFile
    $standInId = [int][File]::ReadAllText($standInFile).Trim()
    $standInRunning = $null -ne (Get-Process -Id $standInId -ErrorAction SilentlyContinue)

    # Assert
    Assert-That -Condition $finished `
        -Message 'The captured output is read to its end within a minute, while the stand-in sleeps for two'
    Assert-Equal -Expected "launched$([Environment]::NewLine)" -Actual $read.Result `
        -Message 'and holds what the caller wrote'
    Assert-That -Condition $standInStarted -Message 'The stand-in editor did start'
    Assert-That -Condition $standInRunning `
        -Message 'and was still running when the read finished, so the read did not wait for it'
}
finally {
    if (Test-Path -LiteralPath $standInFile) {
        $leftover = [int][File]::ReadAllText($standInFile).Trim()
        Stop-Process -Id $leftover -Force -ErrorAction SilentlyContinue
    }

    if ($null -ne $caller) {
        if (-not $caller.HasExited) {
            $caller.Kill($true)
        }

        $caller.Dispose()
    }

    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
