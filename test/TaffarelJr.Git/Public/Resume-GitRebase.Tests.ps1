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

    # The caller's own editor, which git would start for the commit message
    # if nothing outranked it: here it leaves a marker instead.
    $marker = Join-Path ([System.IO.Path]::GetTempPath()) "editor-marker-$([Guid]::NewGuid()).txt"
    $env:GIT_EDITOR = "echo editor-was-launched >> '$($marker -replace '\\', '/')' #"
    try {
        $result = Resume-GitRebase -RepoPath $repo
    }
    finally {
        Remove-Item Env:GIT_EDITOR
    }

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $marker) `
        -Message 'A GIT_EDITOR in the caller''s environment is never started'
    Assert-Equal -Expected $false -Actual $result.Conflict `
        -Message 'Continuing after a resolved conflict finishes cleanly'
    Assert-Equal -Expected @('Conflict', 'Paths') -Actual @($result.PSObject.Properties.Name) `
        -Message 'A clean result has Paths too, so reading it never throws under strict mode'
    Assert-Equal -Expected 0 -Actual $result.Paths.Count -Message 'and it is empty'
    Assert-Equal -Expected $false -Actual (Test-GitRebaseInProgress -RepoPath $repo) `
        -Message 'The rebase is no longer in progress'
    Assert-Equal -Expected 'feature change' -Actual (Get-GitCommit -RepoPath $repo).Subject `
        -Message "feature's commit was replayed"
    Assert-Equal -Expected 'feature' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) `
        -Message "feature's own content made it through the replay"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a rebase over two commits that both conflict, resolved one at a time
    git -C $repo checkout -q -b multi main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'x.txt') -Value 'x-multi' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'multi: x' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'y.txt') -Value 'y-multi' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'multi: y' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'x.txt') -Value 'x-main' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'y.txt') -Value 'y-main' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'main: x and y' 2>&1 | Out-Null
    git -C $repo checkout -q multi 2>&1 | Out-Null
    $first = Start-GitRebase -Ref 'main' -RepoPath $repo
    Resolve-GitConflict -Path 'x.txt' -Side Theirs -RepoPath $repo

    # Act - continuing runs into the second commit's conflict
    $second = Resume-GitRebase -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'x.txt' -Actual $first.Paths[0] -Message 'The first stop is on the first commit'
    Assert-Equal -Expected $true -Actual $second.Conflict -Message 'Continuing into a second conflict reports it'
    Assert-Equal -Expected 'y.txt' -Actual $second.Paths[0] -Message 'with the paths that are conflicted now'

    #───────────────────────────────────────────────────────────────────────────
    # Act - continuing with a rebase that is not there is an error
    git -C $repo rebase --abort 2>&1 | Out-Null

    # Assert
    Assert-Throws -ScriptBlock {
        Resume-GitRebase -RepoPath $repo
    } -MessageLike '*Continuing the rebase failed:*' `
        -Message 'With no rebase under way it throws, quoting git, instead of calling it a conflict'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a rebase paused on a resolved conflict, and an unstaged change to
# another file
$repo = New-GitTestPathRepo -Path 'b.txt'
try {
    git -C $repo checkout -q -b feature 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'feature' -NoNewline
    git -C $repo commit --quiet -am 'feature change' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'main' -NoNewline
    git -C $repo commit --quiet -am 'main change' 2>&1 | Out-Null
    git -C $repo checkout -q feature 2>&1 | Out-Null
    git -C $repo rebase main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'resolved' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'unstaged' -NoNewline

    # Act / Assert
    Assert-Throws -ScriptBlock { Resume-GitRebase -RepoPath $repo } `
        -MessageLike '*Continuing the rebase failed:*' `
        -Message 'A rebase git will not continue, with no conflict left, throws, quoting git'
    Assert-Equal -Expected $true -Actual (Test-GitRebaseInProgress -RepoPath $repo) `
        -Message 'and the rebase is still paused'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
