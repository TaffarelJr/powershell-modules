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
    # Arrange - a conflict between two branches
    git -C $repo checkout -q -b branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-a' -NoNewline
    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-main' -NoNewline
    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null

    # Act - keep our side
    Resolve-GitConflict -Path 'a.txt' -Side Ours -RepoPath $repo

    # Assert - "ours" reproduces HEAD's own content for this path, so there is
    # genuinely nothing staged relative to HEAD once it is resolved this way
    Assert-Equal -Expected 0 -Actual (Get-GitConflict -RepoPath $repo).Count -Message 'The path is no longer conflicted'
    Assert-Equal -Expected 'from-main' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) `
        -Message 'Ours keeps the current branch''s content'
    git -C $repo merge --abort 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the same conflict again, resolved the other way
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null

    # Act
    Resolve-GitConflict -Path 'a.txt' -Side Theirs -RepoPath $repo

    # Assert - "theirs" genuinely differs from HEAD, so this resolution does
    # show up as a real staged change
    Assert-Equal -Expected 'from-a' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) `
        -Message 'Theirs keeps the incoming branch''s content'
    Assert-Equal -Expected $true -Actual (Test-GitChange -Staged -RepoPath $repo) -Message 'The resolution is staged'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
