#Requires -Version 7.4
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Read by the script block or child process the test hands it to, by scope.')]
param()

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
    # Arrange - a feature branch with no conflicting changes
    git -C $repo checkout -q -b feature 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add b' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null

    # Act
    $clean = Merge-GitBranch -Ref 'feature' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual $clean.Conflict -Message 'A clean merge reports no conflict'
    Assert-Equal -Expected @('Conflict', 'Paths') -Actual @($clean.PSObject.Properties.Name) `
        -Message 'A clean result has Paths too, so reading it never throws under strict mode'
    Assert-Equal -Expected 0 -Actual $clean.Paths.Count -Message 'and it is empty'
    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath (Join-Path $repo 'b.txt')) `
        -Message "feature's file is now present"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a fast-forward-able branch
    git -C $repo checkout -q -b ff-branch 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'c' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add c' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    $beforeHead = (git -C $repo rev-parse HEAD).Trim()

    # Act - -NoFastForward always creates a merge commit
    Merge-GitBranch -Ref 'ff-branch' -NoFastForward -RepoPath $repo | Out-Null
    $log = @(Get-GitLog -Count 1 -RepoPath $repo)

    # Assert
    Assert-That -Condition ($log[0].Subject -like 'Merge*') `
        -Message '-NoFastForward creates a real merge commit instead of fast-forwarding'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two branches that conflict on the same file
    git -C $repo checkout -q -b conflict-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-a' -NoNewline
    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-main' -NoNewline
    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null

    # Act
    $conflicted = Merge-GitBranch -Ref 'conflict-a' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $conflicted.Conflict -Message 'A conflicting merge reports a conflict'
    Assert-Equal -Expected 'a.txt' -Actual $conflicted.Paths[0] -Message 'The conflicted path is reported'
    git -C $repo merge --abort 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - diverged branches that merge cleanly, in a repo whose config
    # allows only fast-forward merges
    git -C $repo checkout -q -b side 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'side.txt') -Value 'side' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'side change' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    git -C $repo commit --quiet --allow-empty -m 'main moves on' 2>&1 | Out-Null
    git -C $repo config merge.ff only 2>&1 | Out-Null

    # Act
    $diverged = Merge-GitBranch -Ref 'side' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual $diverged.Conflict `
        -Message 'A merge that cannot fast-forward makes a merge commit whatever merge.ff says'
    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath (Join-Path $repo 'side.txt')) `
        -Message 'and brings the branch in'
    git -C $repo config --unset merge.ff 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a merge that fails without conflicting is an error, with git's reason
    Assert-Throws -ScriptBlock {
        Merge-GitBranch -Ref 'no-such-branch' -RepoPath $repo
    } -MessageLike '*Merging no-such-branch failed:*no-such-branch*' `
        -Message 'A ref that does not exist throws, quoting git'

    #───────────────────────────────────────────────────────────────────────────
    # Act - and it is an error in a folder that is no repository too,
    # with the merge's own message rather than one about conflicts
    $plain = Join-Path ([System.IO.Path]::GetTempPath()) "not-a-repo-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $plain | Out-Null

    # Assert
    try {
        Assert-Throws -ScriptBlock {
            Merge-GitBranch -Ref 'main' -RepoPath $plain
        } -MessageLike '*Merging main failed:*not a git repository*' `
            -Message 'Outside a repository the message is the merge''s own'
    }
    finally {
        Remove-Item -LiteralPath $plain -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an uncommitted change the merge would overwrite
$repo = New-GitTestRepo
try {
    git -C $repo checkout -q -b incoming 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'incoming' -NoNewline
    git -C $repo commit --quiet -am 'incoming change' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'uncommitted' -NoNewline

    # Act / Assert
    Assert-Throws -ScriptBlock { Merge-GitBranch -Ref 'incoming' -RepoPath $repo } `
        -MessageLike '*Merging incoming failed:*overwritten by merge*' `
        -Message 'A merge git refuses before it starts throws, quoting git, instead of calling it a conflict'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
