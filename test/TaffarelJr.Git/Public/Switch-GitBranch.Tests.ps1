#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$repo = New-GitTestRepo
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    git -C $repo branch feature 2>&1 | Out-Null

    # Act - switching to an existing branch
    Switch-GitBranch -Name 'feature' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'feature' -Actual (Get-GitBranch -RepoPath $repo) -Message 'Checks the branch out'

    #───────────────────────────────────────────────────────────────────────────
    # Act - switching to a branch that does not exist throws
    git -C $repo checkout -q main 2>&1 | Out-Null

    # Assert
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'nope' -RepoPath $repo } `
        -MessageLike "*Switching to nope failed: there is no branch named 'nope'*-Create*" `
        -Message 'Switching to a nonexistent branch without -Create throws'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tracked folder and a tracked file, both with edits not yet
    # committed, and no branch named like either
    New-Item -ItemType Directory -Path (Join-Path $repo 'docs') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'docs/guide.md') -Value 'v1' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add guide' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'docs/guide.md') -Value 'unsaved guide' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'unsaved a' -NoNewline

    # Act / Assert
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'docs' -RepoPath $repo } `
        -MessageLike "*there is no branch named 'docs'*" `
            -Message 'A folder named like the branch is not checked out in its place'
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'a.txt' -RepoPath $repo } `
        -MessageLike "*there is no branch named 'a.txt'*" -Message 'nor is a file'
    Assert-Equal -Expected 'unsaved guide' -Actual (Get-Content -LiteralPath (Join-Path $repo 'docs/guide.md') -Raw) `
        -Message 'so the uncommitted edit in the folder is kept'
    Assert-Equal -Expected 'unsaved a' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) `
        -Message 'and so is the one in the file'
    Assert-Equal -Expected 'main' -Actual (Get-GitBranch -RepoPath $repo) -Message 'and the branch has not changed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a branch named like the tracked folder, with the edit still there
    git -C $repo branch docs 2>&1 | Out-Null

    # Act
    Switch-GitBranch -Name 'docs' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'docs' -Actual (Get-GitBranch -RepoPath $repo) `
        -Message 'A branch named like a folder is switched to'
    Assert-Equal -Expected 'unsaved guide' -Actual (Get-Content -LiteralPath (Join-Path $repo 'docs/guide.md') -Raw) `
        -Message 'carrying the uncommitted edit along'
    git -C $repo checkout -q main 2>&1 | Out-Null
    git -C $repo reset -q --hard 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tag, which is not a branch
    git -C $repo tag v1 2>&1 | Out-Null

    # Act / Assert
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'v1' -RepoPath $repo } `
        -MessageLike "*there is no branch named 'v1' ('v1' is refs/tags/v1)*-Create*" `
            -Message 'A tag is not switched to, and the message says what it is'
    Assert-Equal -Expected 'main' -Actual (Get-GitBranch -RepoPath $repo) -Message 'so HEAD is not detached at it'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'HEAD~1' -RepoPath $repo } `
        -MessageLike "*there is no branch named 'HEAD~1' ('HEAD~1' is a revision, not a branch)*" `
            -Message 'A commit is not switched to'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - feature was checked out before main
    git -C $repo checkout -q feature 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null

    # Act
    Switch-GitBranch -Name '@{-1}' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'feature' -Actual (Get-GitBranch -RepoPath $repo) `
        -Message '@{-1} switches to the previous branch'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    Switch-GitBranch -Name 'refs/heads/main' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'main' -Actual (Get-GitBranch -RepoPath $repo) `
        -Message 'A full refs/heads/ name switches to that branch, without detaching HEAD'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -Create makes a new branch from a start point
    Switch-GitBranch -Name 'new-branch' -Create -StartPoint 'feature' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'new-branch' -Actual (Get-GitBranch -RepoPath $repo) `
        -Message '-Create switches to the new branch'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'feature' -RepoPath $repo) `
        -Actual (Resolve-GitRef -Ref 'new-branch' -RepoPath $repo) `
        -Message '-Create starts the branch at -StartPoint'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a commit only the existing branch has
    git -C $repo commit --quiet --allow-empty -m 'only on new-branch' 2>&1 | Out-Null
    $tip = Resolve-GitRef -Ref 'new-branch' -RepoPath $repo
    git -C $repo checkout -q main 2>&1 | Out-Null

    # Act / Assert - -Create on an existing branch
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'new-branch' -Create -StartPoint 'main' -RepoPath $repo } `
        -MessageLike ("Switching to new-branch failed: a branch named 'new-branch' already exists." +
            " Switch to it without -Create.") `
        -Message '-Create refuses a branch that exists, naming the plain switch'

    # Assert
    Assert-Equal -Expected $tip -Actual (Resolve-GitRef -Ref 'new-branch' -RepoPath $repo) `
        -Message 'and leaves it where it was, so its commit is not left in the reflog alone'
    Assert-Equal -Expected 'main' -Actual (Get-GitBranch -RepoPath $repo) -Message 'without switching to it'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a clone, and a branch only its remote has
$upstream = New-GitTestRepo
git -C $upstream branch remote-only 2>&1 | Out-Null
$clone = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
git clone --quiet $upstream $clone 2>&1 | Out-Null
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'remote-only' -RepoPath $clone } `
        -MessageLike "*there is no branch named 'remote-only'*" `
            -Message 'A branch only the remote has is not created behind the caller''s back'
    Assert-Equal -Expected 'main' -Actual ((Get-GitBranch -List -RepoPath $clone) -join ', ') `
        -Message 'so no local branch appears'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$plain = New-GitTestFolder
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'main' -RepoPath $plain } `
        -MessageLike '*Switching to main failed (exit 128)*not a git repository*' `
        -Message 'A folder that is no repository says so, rather than that the branch is missing'
}
finally {
    Remove-GitTestRepo -Path $plain
}

exit (Complete-TestRun)
