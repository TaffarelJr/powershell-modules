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

function New-DivergedClone {
    <#
    .SYNOPSIS
        Makes an upstream repository and a clone of it that have each committed
        since, so the clone's branch and its upstream have diverged.
    .PARAMETER Conflicting
        Has both commits change the same file, so bringing them together
        conflicts.
    .PARAMETER PullRebase
        Sets pull.rebase in the clone, as a user's own config would.
    .OUTPUTS
        An object with Upstream and Clone, the two paths.
    #>
    param(
        [switch]$Conflicting,

        [ValidateSet('true', 'false')]
        [string]$PullRebase
    )

    $upstreamPath = New-GitTestRepo
    $clonePath = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
    git clone --quiet $upstreamPath $clonePath 2>&1 | Out-Null
    git -C $clonePath config user.name 'Test' 2>&1 | Out-Null
    git -C $clonePath config user.email 'test@example.com' 2>&1 | Out-Null
    git -C $clonePath config core.autocrlf false 2>&1 | Out-Null
    if ($PullRebase) {
        git -C $clonePath config pull.rebase $PullRebase 2>&1 | Out-Null
    }

    $upstreamFile = if ($Conflicting) { 'a.txt' } else { 'upstream.txt' }
    $localFile = if ($Conflicting) { 'a.txt' } else { 'local.txt' }
    Set-Content -LiteralPath (Join-Path $upstreamPath $upstreamFile) -Value 'from upstream' -NoNewline
    git -C $upstreamPath add -A 2>&1 | Out-Null
    git -C $upstreamPath commit --quiet -m 'upstream change' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $clonePath $localFile) -Value 'from local' -NoNewline
    git -C $clonePath add -A 2>&1 | Out-Null
    git -C $clonePath commit --quiet -m 'local change' 2>&1 | Out-Null

    return [PSCustomObject]@{
        Upstream = $upstreamPath
        Clone    = $clonePath
    }
}

function Get-MergeCommitCount {
    <#
    .SYNOPSIS
        Counts the merge commits in a repository's history.
    .PARAMETER RepoPath
        The repository.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$RepoPath
    )

    return @(git -C $RepoPath log --merges --format=%H).Count
}

$upstream = New-GitTestRepo
$repo = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a clone, then a new commit upstream
    git clone --quiet $upstream $repo 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $upstream 'b.txt') -Value 'b' -NoNewline
    git -C $upstream add -A 2>&1 | Out-Null
    git -C $upstream commit --quiet -m 'second' 2>&1 | Out-Null

    # Act
    $pulled = Update-GitBranch -RepoPath $repo

    # Assert
    Assert-Equal -Expected (Resolve-GitRef -Ref 'main' -RepoPath $upstream) `
        -Actual (Resolve-GitRef -Ref 'HEAD' -RepoPath $repo) `
        -Message 'Pulling brings the local branch up to date with upstream'
    Assert-Equal -Expected $false -Actual $pulled.Conflict -Message 'A clean pull reports no conflict'
    Assert-Equal -Expected @('Conflict', 'Paths') -Actual @($pulled.PSObject.Properties.Name) `
        -Message 'A clean result has Paths too, so reading it never throws under strict mode'
    Assert-Equal -Expected 0 -Actual $pulled.Paths.Count -Message 'and it is empty'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - diverging histories on both sides
    Set-Content -LiteralPath (Join-Path $upstream 'c.txt') -Value 'c' -NoNewline
    git -C $upstream add -A 2>&1 | Out-Null
    git -C $upstream commit --quiet -m 'upstream change' 2>&1 | Out-Null

    Set-Content -LiteralPath (Join-Path $repo 'd.txt') -Value 'd' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'local change' 2>&1 | Out-Null

    # Act - -Rebase replays the local commit on top instead of merging
    Update-GitBranch -Rebase -RepoPath $repo

    # Assert
    $log = @(Get-GitLog -Count 3 -RepoPath $repo)
    Assert-Equal -Expected 'local change' -Actual $log[0].Subject -Message '-Rebase replays the local commit on top'
    Assert-Equal -Expected 'upstream change' -Actual $log[1].Subject -Message 'The upstream commit now comes before it'
    Assert-That -Condition ($log.Subject -notcontains 'Merge') -Message 'No merge commit is created'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a clone whose current branch is not the one to pull
$pair = New-DivergedClone
try {
    git -C $pair.Clone checkout -q -b scratch 2>&1 | Out-Null
    git -C $pair.Clone branch --set-upstream-to=origin/main scratch 2>&1 | Out-Null

    # Act - pulling a named branch, into whatever is checked out
    $named = Update-GitBranch -Branch 'main' -RepoPath $pair.Clone

    # Assert
    Assert-Equal -Expected $false -Actual $named.Conflict -Message 'Pulling a named -Branch works'
    Assert-That -Condition (Test-GitAncestor -Ancestor 'origin/main' -Descendant 'HEAD' -RepoPath $pair.Clone) `
        -Message 'and brings in what that branch has'
}
finally {
    Remove-GitTestRepo -Path $pair.Upstream
    Remove-GitTestRepo -Path $pair.Clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a local branch with no upstream configured, named like a branch
# the remote has moved on
$pair = New-DivergedClone
try {
    git -C $pair.Upstream branch feature 2>&1 | Out-Null
    git -C $pair.Clone fetch --quiet origin 2>&1 | Out-Null
    git -C $pair.Clone checkout -q --no-track -b feature origin/main~1 2>&1 | Out-Null

    # Act
    $loose = Update-GitBranch -RepoPath $pair.Clone

    # Assert
    Assert-Equal -Expected $false -Actual $loose.Conflict `
        -Message 'With no upstream, -Branch defaults to the current branch''s name'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'origin/feature' -RepoPath $pair.Clone) `
        -Actual (Resolve-GitRef -Ref 'HEAD' -RepoPath $pair.Clone) `
        -Message 'and pulls the remote branch of that name'

    # Act - and a detached HEAD has no name to default to
    git -C $pair.Clone checkout -q --detach 2>&1 | Out-Null

    # Assert
    Assert-Throws -ScriptBlock { Update-GitBranch -RepoPath $pair.Clone } `
        -MessageLike '*Pulling failed: HEAD is detached*pass -Branch*' `
            -Message 'A detached HEAD with no -Branch says so'
}
finally {
    Remove-GitTestRepo -Path $pair.Upstream
    Remove-GitTestRepo -Path $pair.Clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - diverged, with no pull.rebase set anywhere. Left to itself git
# refuses to guess how to reconcile the two.
$pair = New-DivergedClone
try {
    # Act
    $merged = Update-GitBranch -RepoPath $pair.Clone

    # Assert
    Assert-Equal -Expected $false -Actual $merged.Conflict `
        -Message 'Merging diverged branches works with no pull.rebase configured'
    Assert-Equal -Expected 1 -Actual (Get-MergeCommitCount -RepoPath $pair.Clone) -Message 'by making a merge commit'
}
finally {
    Remove-GitTestRepo -Path $pair.Upstream
    Remove-GitTestRepo -Path $pair.Clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - diverged, with the user's own config saying pull should rebase
$pair = New-DivergedClone -PullRebase true
try {
    # Act - a merge is what was asked for
    $null = Update-GitBranch -RepoPath $pair.Clone

    # Assert
    Assert-Equal -Expected 1 -Actual (Get-MergeCommitCount -RepoPath $pair.Clone) `
        -Message 'A user''s pull.rebase=true does not turn a requested merge into a rebase'
}
finally {
    Remove-GitTestRepo -Path $pair.Upstream
    Remove-GitTestRepo -Path $pair.Clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - diverged, with the user's own config saying pull should merge
$pair = New-DivergedClone -PullRebase false
try {
    # Act - a rebase is what was asked for
    $null = Update-GitBranch -Rebase -RepoPath $pair.Clone

    # Assert
    Assert-Equal -Expected 0 -Actual (Get-MergeCommitCount -RepoPath $pair.Clone) `
        -Message 'A user''s pull.rebase=false does not turn a requested rebase into a merge'
    Assert-Equal -Expected 'local change' -Actual (Get-GitCommit -RepoPath $pair.Clone).Subject `
        -Message 'The local commit was replayed on top'
}
finally {
    Remove-GitTestRepo -Path $pair.Upstream
    Remove-GitTestRepo -Path $pair.Clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - diverged over the same file, so merging cannot finish by itself
$pair = New-DivergedClone -Conflicting
try {
    # Act
    $conflicted = Update-GitBranch -RepoPath $pair.Clone

    # Assert
    Assert-Equal -Expected $true -Actual $conflicted.Conflict `
        -Message 'A conflicting pull reports a conflict instead of throwing'
    Assert-Equal -Expected 'a.txt' -Actual $conflicted.Paths[0] -Message 'with the conflicted path'
    Assert-That -Condition ($null -ne (Resolve-GitRef -Ref 'MERGE_HEAD' -RepoPath $pair.Clone)) `
        -Message 'and the merge is left under way for the caller to finish'
}
finally {
    Remove-GitTestRepo -Path $pair.Upstream
    Remove-GitTestRepo -Path $pair.Clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same conflict, pulled with -Rebase
$pair = New-DivergedClone -Conflicting
try {
    # Act
    $rebaseConflict = Update-GitBranch -Rebase -RepoPath $pair.Clone

    # Assert
    Assert-Equal -Expected $true -Actual $rebaseConflict.Conflict `
        -Message 'A conflicting pull --rebase reports a conflict too'
    Assert-Equal -Expected $true -Actual (Test-GitRebaseInProgress -RepoPath $pair.Clone) `
        -Message 'and leaves the rebase paused'
}
finally {
    Remove-GitTestRepo -Path $pair.Upstream
    Remove-GitTestRepo -Path $pair.Clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a pull that fails for some other reason is an error
$lone = New-GitTestRepo

# Assert
try {
    Assert-Throws -ScriptBlock {
        Update-GitBranch -Remote 'no-such-remote' -RepoPath $lone
    } -MessageLike '*Pulling failed:*no-such-remote*' -Message 'A remote that does not exist throws, quoting git'
    Assert-Throws -ScriptBlock {
        Update-GitBranch -Remote '--upload-pack=echo-not-run' -RepoPath $lone
    } -MessageLike "*starts with '-'*" -Message 'A remote starting with a dash is refused'
}
finally {
    Remove-GitTestRepo -Path $lone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a local 'topic' that tracks origin/main, while the remote also has
# a 'topic' of its own; both remote branches then move on
$upstream = New-GitTestRepo
git -C $upstream branch topic 2>&1 | Out-Null
$clone = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
git clone --quiet $upstream $clone 2>&1 | Out-Null
git -C $clone checkout -q -b topic origin/main 2>&1 | Out-Null
Set-Content -LiteralPath (Join-Path $upstream 'on-main.txt') -Value 'm' -NoNewline
git -C $upstream add -A 2>&1 | Out-Null
git -C $upstream commit --quiet -m 'on main' 2>&1 | Out-Null
git -C $upstream checkout -q topic 2>&1 | Out-Null
Set-Content -LiteralPath (Join-Path $upstream 'on-topic.txt') -Value 't' -NoNewline
git -C $upstream add -A 2>&1 | Out-Null
git -C $upstream commit --quiet -m 'on topic' 2>&1 | Out-Null
try {
    # Act
    $pulled = Update-GitBranch -RepoPath $clone

    # Assert
    Assert-Equal -Expected $false -Actual $pulled.Conflict `
        -Message 'A branch tracking a differently named upstream pulls'
    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath (Join-Path $clone 'on-main.txt')) `
        -Message 'from the upstream it tracks'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $clone 'on-topic.txt')) `
        -Message 'and not from the remote branch that shares its name'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$upstream = New-GitTestRepo
$clone = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
git clone --quiet $upstream $clone 2>&1 | Out-Null
try {
    # Act / Assert - a branch the remote does not have
    Assert-Throws -ScriptBlock { Update-GitBranch -Branch 'no-such-branch' -RepoPath $clone } `
        -MessageLike '*Pulling failed:*no-such-branch*' `
        -Message 'A remote branch that does not exist throws, quoting git, instead of calling it a conflict'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a clone that is only behind its upstream
$upstream = New-GitTestRepo
$clone = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
git clone --quiet $upstream $clone 2>&1 | Out-Null
git -C $upstream commit --quiet --allow-empty -m 'ahead upstream' 2>&1 | Out-Null
try {
    # Act
    $forwarded = Update-GitBranch -FastForwardOnly -RepoPath $clone

    # Assert
    Assert-Equal -Expected (Resolve-GitRef -Ref 'main' -RepoPath $upstream) `
        -Actual (Resolve-GitRef -Ref 'HEAD' -RepoPath $clone) `
        -Message '-FastForwardOnly moves a branch that is only behind up to its upstream'
    Assert-Equal -Expected $false -Actual $forwarded.Conflict -Message 'and reports no conflict'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $clone
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a clone and its upstream that have each committed since
$pair = New-DivergedClone
try {
    $before = Resolve-GitRef -Ref 'HEAD' -RepoPath $pair.Clone

    # Act / Assert
    Assert-Throws -ScriptBlock { Update-GitBranch -FastForwardOnly -RepoPath $pair.Clone } `
        -MessageLike 'Pulling failed: *fast-forward*' `
        -Message '-FastForwardOnly throws for a branch that has diverged, with git''s reason'

    # Assert
    Assert-Equal -Expected $before -Actual (Resolve-GitRef -Ref 'HEAD' -RepoPath $pair.Clone) `
        -Message 'and leaves the branch where it was'
    Assert-Equal -Expected 0 -Actual (Get-MergeCommitCount -RepoPath $pair.Clone) -Message 'with no merge commit made'
}
finally {
    Remove-GitTestRepo -Path $pair.Upstream
    Remove-GitTestRepo -Path $pair.Clone
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert
Assert-Throws -ScriptBlock { Update-GitBranch -FastForwardOnly -Rebase } `
    -MessageLike 'Parameter set cannot be resolved*' `
    -Message '-FastForwardOnly and -Rebase cannot be given together'

exit (Complete-TestRun)
