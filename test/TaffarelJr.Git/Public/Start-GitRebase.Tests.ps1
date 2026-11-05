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
    # Arrange - a feature branch with no conflicting changes
    git -C $repo checkout -q -b feature 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'feature commit' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'c' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'main commit' 2>&1 | Out-Null
    git -C $repo checkout -q feature 2>&1 | Out-Null

    # Act
    $clean = Start-GitRebase -Ref 'main' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual $clean.Conflict -Message 'A clean rebase reports no conflict'
    Assert-Equal -Expected @('Conflict', 'Paths') -Actual @($clean.PSObject.Properties.Name) `
        -Message 'A clean result has Paths too, so reading it never throws under strict mode'
    Assert-Equal -Expected 0 -Actual $clean.Paths.Count -Message 'and it is empty'
    $log = @(Get-GitLog -Count 2 -RepoPath $repo)
    Assert-Equal -Expected 'feature commit' -Actual $log[0].Subject -Message "feature's commit is replayed on top"
    Assert-Equal -Expected 'main commit' -Actual $log[1].Subject -Message "main's commit now comes first"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a conflicting rebase
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'main-again' -NoNewline
    git -C $repo commit --quiet -am 'main changes c again' 2>&1 | Out-Null
    git -C $repo checkout -q -b conflicting 'feature' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'conflicting' -NoNewline
    git -C $repo commit --quiet -am 'conflicting change to c' 2>&1 | Out-Null

    # Act
    $conflicted = Start-GitRebase -Ref 'main' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $conflicted.Conflict -Message 'A conflicting rebase reports a conflict'
    Assert-Equal -Expected 'c.txt' -Actual $conflicted.Paths[0] -Message 'The conflicted path is reported'
    Assert-Equal -Expected $true -Actual (Test-GitRebaseInProgress -RepoPath $repo) -Message 'The rebase is left paused'
    git -C $repo rebase --abort 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a rebase that cannot start is an error, not a conflict
    Assert-Throws -ScriptBlock {
        Start-GitRebase -Ref 'no-such-branch' -RepoPath $repo
    } -MessageLike '*Rebasing onto no-such-branch failed:*no-such-branch*' `
        -Message 'A ref that does not exist throws, quoting git'

    #───────────────────────────────────────────────────────────────────────────
    # Act - and so is one in a folder that is no repository
    $plain = Join-Path ([System.IO.Path]::GetTempPath()) "not-a-repo-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $plain | Out-Null

    # Assert
    try {
        Assert-Throws -ScriptBlock {
            Start-GitRebase -Ref 'main' -RepoPath $plain
        } -MessageLike '*Rebasing onto main failed:*not a git repository*' `
            -Message 'Outside a repository the message is the rebase''s own'
    }
    finally {
        Remove-Item -LiteralPath $plain -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an unstaged change, which git will not rebase over
$repo = New-GitTestRepo
try {
    git -C $repo branch base 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'unstaged' -NoNewline

    # Act / Assert
    Assert-Throws -ScriptBlock { Start-GitRebase -Ref 'base' -RepoPath $repo } `
        -MessageLike '*Rebasing onto base failed:*unstaged changes*' `
        -Message 'A rebase git refuses to start throws, quoting git'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
