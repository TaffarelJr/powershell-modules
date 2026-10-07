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
    # Arrange - a rebase paused on a conflict
    git -C $repo checkout -q -b feature 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'feature' -NoNewline
    git -C $repo commit --quiet -am 'feature change' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'main' -NoNewline
    git -C $repo commit --quiet -am 'main change' 2>&1 | Out-Null
    git -C $repo checkout -q feature 2>&1 | Out-Null
    git -C $repo rebase main 2>&1 | Out-Null

    # Act - resolve and continue. -Side Theirs, not Ours: a rebase swaps the
    # usual meaning, so "ours" here is main (the base being replayed onto)
    # and "theirs" is the feature commit actually being replayed - picking
    # Ours would make the replayed patch a no-op and git would skip it
    # entirely, leaving no new commit to assert against.
    Resolve-GitConflict -Path 'a.txt' -Side Theirs -RepoPath $repo
    $result = Resume-GitRebase -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual $result.Conflict -Message 'Continuing after a resolved conflict finishes cleanly'
    Assert-Equal -Expected $false -Actual (Test-GitRebaseInProgress -RepoPath $repo) -Message 'The rebase is no longer in progress'
    Assert-Equal -Expected 'feature change' -Actual (Get-GitCommit -RepoPath $repo).Subject -Message "feature's commit was replayed"
    Assert-Equal -Expected 'feature' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) `
        -Message "feature's own content made it through the replay"
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
