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

$remote = New-GitTestRepo -NoCommit
git -C $remote 'config' 'receive.denyCurrentBranch' 'ignore' 2>&1 | Out-Null
$repo = New-GitTestRepo
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-GitRemote -Name 'origin' -Url $remote -RepoPath $repo

    # Act - the first push, with -SetUpstream
    $sent = Push-GitCommit -SetUpstream -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $sent -Message 'A push that actually sends commits reports true'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'HEAD' -RepoPath $repo) `
        -Actual (Resolve-GitRef -Ref 'main' -RepoPath $remote) `
        -Message 'The remote now has the pushed commit'

    #───────────────────────────────────────────────────────────────────────────
    # Act - pushing again with nothing new
    $sentAgain = Push-GitCommit -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual $sentAgain -Message 'A push with nothing new reports false'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the remote moves ahead independently
    Set-Content -LiteralPath (Join-Path $remote 'remote-only.txt') -Value 'x' -NoNewline
    git -C $remote add -A 2>&1 | Out-Null
    git -C $remote commit --quiet -m 'remote-only change' 2>&1 | Out-Null

    Set-Content -LiteralPath (Join-Path $repo 'local-only.txt') -Value 'y' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'local-only change' 2>&1 | Out-Null

    # Act / Assert - a push that would overwrite remote history is refused
    Assert-Throws -ScriptBlock { Push-GitCommit -RepoPath $repo } -MessageLike '*Pushing failed*rejected*' `
        -Message 'A diverged push is refused without -Force'
    Assert-Throws -ScriptBlock { Push-GitCommit -Force -ForceWithoutLease -RepoPath $repo } `
        -MessageLike '*Parameter set cannot be resolved*' `
            -Message '-Force and -ForceWithoutLease together are refused, not one quietly winning'

    # Act - -ForceWithoutLease pushes anyway
    $forced = Push-GitCommit -ForceWithoutLease -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $forced -Message '-ForceWithoutLease overwrites the diverged remote branch'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'HEAD' -RepoPath $repo) `
        -Actual (Resolve-GitRef -Ref 'main' -RepoPath $remote) `
        -Message 'The remote now matches the local branch'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the remote moves on again, unseen, and the local branch has a new commit too
    Set-Content -LiteralPath (Join-Path $remote 'unseen.txt') -Value 'z' -NoNewline
    git -C $remote add -A 2>&1 | Out-Null
    git -C $remote commit --quiet -m 'unseen remote change' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'newer.txt') -Value 'n' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'newer local change' 2>&1 | Out-Null

    # Act / Assert - -Force leases against what was last fetched, so it refuses
    Assert-Throws -ScriptBlock { Push-GitCommit -Force -RepoPath $repo } -MessageLike '*Pushing failed*' `
        -Message '-Force refuses to overwrite a remote that moved since it was last fetched'

    # Act - fetch, so the lease matches what is there now
    Sync-GitRemote -RepoPath $repo
    $leased = Push-GitCommit -Force -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $leased -Message '-Force pushes once the remote is what was last fetched'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'HEAD' -RepoPath $repo) `
        -Actual (Resolve-GitRef -Ref 'main' -RepoPath $remote) `
        -Message 'and the remote now matches the local branch'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a detached HEAD, which has no branch to push
    git -C $repo checkout -q --detach 2>&1 | Out-Null

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Push-GitCommit -RepoPath $repo
    } -MessageLike '*HEAD is detached*pass -Branch*' `
        -Message 'With no -Branch and a detached HEAD, it says so instead of handing git an empty branch name'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a branch that can be named explicitly even then
    Assert-Equal -Expected $false -Actual (Push-GitCommit -Branch 'main' -RepoPath $repo) `
        -Message 'An explicit -Branch pushes from a detached HEAD (nothing new, so $false)'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Push-GitCommit -Branch 'HEAD' -RepoPath $repo } `
        -MessageLike "*Pushing failed: there is no branch named 'HEAD' (HEAD is detached).*" `
        -Message '-Branch HEAD from a detached HEAD says why there is no branch'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - an option-like remote
    Assert-Throws -ScriptBlock {
        Push-GitCommit -Remote '--receive-pack=echo-not-run' -Branch 'main' -RepoPath $repo
    } -MessageLike "*starts with '-'*" -Message 'A remote starting with a dash is refused'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - back on the branch, with a new commit, and a tag named like the
    # branch on an older commit
    git -C $repo checkout -q main 2>&1 | Out-Null
    git -C $repo commit --quiet --allow-empty -m 'after the tag' 2>&1 | Out-Null
    git -C $repo tag main HEAD~1 2>&1 | Out-Null

    # Act
    $pushedBranch = Push-GitCommit -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $pushedBranch `
        -Message 'A tag named like the branch does not stop the branch being pushed'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'refs/heads/main' -RepoPath $repo) `
        -Actual (Resolve-GitRef -Ref 'refs/heads/main' -RepoPath $remote) `
        -Message 'and it is the branch that arrives, not the tag'
    Assert-Equal -Expected $null -Actual (Resolve-GitRef -Ref 'refs/tags/main' -RepoPath $remote) `
        -Message 'with no tag sent along'
    Assert-Equal -Expected 'refs/heads/main' -Actual (Get-GitConfig -Name 'branch.main.merge' -RepoPath $repo) `
        -Message 'and -SetUpstream earlier set the upstream to the branch of the same name'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - one more commit to send
    git -C $repo commit --quiet --allow-empty -m 'for HEAD' 2>&1 | Out-Null

    # Act
    $pushedHead = Push-GitCommit -Branch 'HEAD' -RepoPath $repo
    $pushedFull = Push-GitCommit -Branch 'refs/heads/main' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $pushedHead -Message '-Branch HEAD pushes the current branch'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'refs/heads/main' -RepoPath $repo) `
        -Actual (Resolve-GitRef -Ref 'refs/heads/main' -RepoPath $remote) `
        -Message 'to the remote branch of its own name'
    Assert-Equal -Expected $false -Actual $pushedFull `
        -Message 'A full refs/heads/ name is the same branch (nothing new, so $false)'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    git -C $repo tag v-old HEAD~1 2>&1 | Out-Null

    # Act / Assert
    Assert-Throws -ScriptBlock { Push-GitCommit -Branch 'v-old' -RepoPath $repo } `
        -MessageLike "*Pushing failed: there is no branch named 'v-old' ('v-old' is refs/tags/v-old).*" `
        -Message 'A tag is not pushed as a branch'
}
finally {
    Remove-GitTestRepo -Path $remote
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
