#Requires -Version 7.4
using namespace System.Diagnostics
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'ProcessInvocationTestHelper.ps1')
. (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/Private/Stop-NativeProcessTree.ps1')

# Only Windows keeps an orphan's parent id, which is what finds it; elsewhere
# the function is Process.Kill($true) and nothing more.
if (-not $IsWindows) {
    exit (Skip-TestRun -Reason 'finding a process whose parent has exited is Windows-only')
}

$root = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $root | Out-Null
$ids = [System.Collections.Generic.List[int]]::new()
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a running process that has started another
    $pidFile = Join-Path $root 'living.pid'
    $script = "`$p = Start-Process -FilePath '$pwsh' -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 120' -NoNewWindow -PassThru; " +
    "`$p.Id | Set-Content -LiteralPath '$pidFile'; Start-Sleep -Seconds 120"
    $parent = [Process]::Start($pwsh, @('-NoProfile', '-Command', $script))
    $ids.Add($parent.Id)
    $childId = Wait-ProcessIdFile -Path $pidFile
    $ids.Add($childId)

    Stop-NativeProcessTree -Process $parent

    # Assert
    Assert-That -Condition (-not (Test-ProcessRunning -Id $parent.Id)) -Message 'The process is killed'
    Assert-That -Condition (-not (Test-ProcessRunning -Id $childId)) -Message 'and so is the process it started'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a process that started another and then exited, leaving it behind
    $pidFile = Join-Path $root 'orphan.pid'
    $script = "`$p = Start-Process -FilePath '$pwsh' -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 120' -NoNewWindow -PassThru; " +
    "`$p.Id | Set-Content -LiteralPath '$pidFile'"
    $parent = [Process]::Start($pwsh, @('-NoProfile', '-Command', $script))
    $ids.Add($parent.Id)
    $orphanId = Wait-ProcessIdFile -Path $pidFile
    $ids.Add($orphanId)
    $parent.WaitForExit(30000) | Out-Null

    Stop-NativeProcessTree -Process $parent

    # Assert
    Assert-That -Condition (-not (Test-ProcessRunning -Id $orphanId)) `
        -Message 'A process outliving the one that started it is found and killed too'
}
finally {
    foreach ($id in $ids) {
        Stop-Process -Id $id -Force -ErrorAction Ignore
    }

    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
