#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$repo = New-GitTestRepo
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - nothing in progress normally
    Assert-Equal -Expected $false -Actual (Test-GitRebaseInProgress -RepoPath $repo) -Message 'A plain repo has no rebase in progress'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a rebase paused on a conflict
    git -C $repo checkout -q -b feature 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'feature' -NoNewline
    git -C $repo commit --quiet -am 'feature change' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'main' -NoNewline
    git -C $repo commit --quiet -am 'main change' 2>&1 | Out-Null
    git -C $repo checkout -q feature 2>&1 | Out-Null
    git -C $repo rebase main 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected $true -Actual (Test-GitRebaseInProgress -RepoPath $repo) -Message 'A paused rebase is detected'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - after aborting
    git -C $repo rebase --abort 2>&1 | Out-Null
    Assert-Equal -Expected $false -Actual (Test-GitRebaseInProgress -RepoPath $repo) -Message 'An aborted rebase is no longer in progress'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
