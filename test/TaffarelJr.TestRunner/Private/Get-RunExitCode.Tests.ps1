#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/Private/Get-RunExitCode.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - the count itself, up to the most a status holds
foreach ($count in 0, 1, 7, 254, 255) {
    Assert-Equal -Expected $count -Actual (Get-RunExitCode -FailedCount $count) `
        -Message "$count failed files exit with $count"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a count that would wrap around to a pass
foreach ($count in 256, 257, 1000) {
    Assert-Equal -Expected 255 -Actual (Get-RunExitCode -FailedCount $count) `
        -Message "$count failed files exit with 255, not a wrapped-around code"
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert - a count that cannot be
Assert-Throws -ScriptBlock {
    Get-RunExitCode -FailedCount -1
} -MessageLike '*FailedCount*' -Message 'A negative count is refused'

exit (Complete-TestRun)
