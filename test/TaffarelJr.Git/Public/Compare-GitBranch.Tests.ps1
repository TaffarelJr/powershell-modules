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

$upstream = New-GitTestRepo
$repo = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a clone with no divergence yet
    git clone --quiet $upstream $repo 2>&1 | Out-Null

    # Act
    $clean = Compare-GitBranch -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual $clean.Ahead -Message 'A fresh clone is not ahead'
    Assert-Equal -Expected 0 -Actual $clean.Behind -Message 'A fresh clone is not behind'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - diverge both sides
    Set-Content -LiteralPath (Join-Path $upstream 'b.txt') -Value 'b' -NoNewline
    git -C $upstream add -A 2>&1 | Out-Null
    git -C $upstream commit --quiet -m 'upstream change' 2>&1 | Out-Null
    git -C $repo fetch --quiet origin 2>&1 | Out-Null

    Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'c' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'local change' 2>&1 | Out-Null

    # Act - explicit -Upstream, since the remote-tracking ref moved via fetch, not pull
    $diverged = Compare-GitBranch -Upstream 'origin/main' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 1 -Actual $diverged.Ahead -Message 'One local commit not on the upstream'
    Assert-Equal -Expected 1 -Actual $diverged.Behind -Message 'One upstream commit not local yet'

    #───────────────────────────────────────────────────────────────────────────
    # Act - no upstream configured for a plain local branch
    git -C $repo branch 'no-upstream' 2>&1 | Out-Null

    # Assert
    Assert-Equal -Expected $null -Actual (Compare-GitBranch -Branch 'no-upstream' -RepoPath $repo) `
        -Message 'A branch with no configured upstream returns $null'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tag named like the branch, on another commit: git reads a
    # bare 'main' as the tag, and abbreviates the branch to 'heads/main'
    git -C $repo tag main HEAD~1 2>&1 | Out-Null

    # Act
    $tagged = Compare-GitBranch -RepoPath $repo

    # Assert
    Assert-Equal -Expected 1 -Actual $tagged.Ahead `
        -Message 'A tag named like the branch does not stop its upstream being found'
    Assert-Equal -Expected 1 -Actual $tagged.Behind -Message 'and the branch is counted, not the tag'
    git -C $repo tag -d main 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a branch named like a tracked file, tracking origin/main
    git -C $repo branch --track 'c.txt' origin/main 2>&1 | Out-Null

    # Act
    $named = Compare-GitBranch -Branch 'c.txt' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual $named.Ahead -Message 'A branch named like a file is compared as the branch'
    Assert-Equal -Expected 0 -Actual $named.Behind -Message 'with its own upstream'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $missing = Compare-GitBranch -Branch 'no-such-branch' -Upstream 'origin/main' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $null -Actual $missing -Message 'A branch that does not exist returns $null'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a detached HEAD has no branch to compare
    git -C $repo checkout -q --detach 2>&1 | Out-Null

    # Assert
    Assert-Equal -Expected $null -Actual (Compare-GitBranch -RepoPath $repo) -Message 'A detached HEAD returns $null'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$plain = New-GitTestFolder
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Compare-GitBranch -RepoPath $plain } `
        -MessageLike '*Reading the current branch failed*not a git repository*' `
        -Message 'A folder that is no repository throws rather than reading as "cannot be determined"'
}
finally {
    Remove-GitTestRepo -Path $plain
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a clone whose main has one commit origin/main lacks, and a tag
# named 'main' one commit behind origin/main
$upstream = New-GitTestRepo
$clone = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
git clone --quiet $upstream $clone 2>&1 | Out-Null
git -C $clone config user.name 'Test' 2>&1 | Out-Null
git -C $clone config user.email 'test@example.com' 2>&1 | Out-Null
git -C $clone commit --quiet --allow-empty -m 'second' 2>&1 | Out-Null
git -C $clone commit --quiet --allow-empty -m 'third' 2>&1 | Out-Null
git -C $clone tag main HEAD~2 2>&1 | Out-Null
git -C $clone update-ref refs/remotes/origin/main HEAD~1 2>&1 | Out-Null
try {
    # Act
    $againstBranch = Compare-GitBranch -Branch 'origin/main' -Upstream 'main' -RepoPath $clone

    # Assert
    Assert-Equal -Expected 0 -Actual $againstBranch.Ahead `
        -Message '-Upstream naming a local branch compares against the branch'
    Assert-Equal -Expected 1 -Actual $againstBranch.Behind -Message 'not against the tag that shares its name'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $clone
}

exit (Complete-TestRun)
