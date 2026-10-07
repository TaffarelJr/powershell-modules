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
    Assert-Equal -Expected 0 -Actual @(Get-GitConflict -RepoPath $repo).Count `
        -Message 'The path is no longer conflicted'
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
    git -C $repo merge --abort 2>&1 | Out-Null
    git -C $repo reset -q --hard 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a merge with two conflicted files this time
    git -C $repo checkout -q branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'second.txt') -Value 'a-second' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add second on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'second.txt') -Value 'main-second' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add second on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null

    # Assert - the setup took: a merge that never started would leave nothing to
    # resolve, and the checks below would pass for the wrong reason
    Assert-Equal -Expected 2 -Actual @(Get-GitConflict -RepoPath $repo).Count `
        -Message 'The merge left both files conflicted'

    # Act - every conflict, straight from Get-GitConflict
    Get-GitConflict -RepoPath $repo | Resolve-GitConflict -Side Theirs -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitConflict -RepoPath $repo).Count `
        -Message 'Piping Get-GitConflict in resolves every conflicted path'
    Assert-Equal -Expected 'a-second' -Actual (Get-Content -LiteralPath (Join-Path $repo 'second.txt') -Raw) `
        -Message 'and each keeps the side asked for'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a conflict in a file named with pattern characters, inside a
# subfolder, next to an edited lookalike the pattern would match; PowerShell is
# in the subfolder
$repo = New-GitTestRepo
try {
    New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/x[1].txt') -Value 'base' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'sub/x1.txt') -Value 'base' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add x files' 2>&1 | Out-Null
    git -C $repo checkout -q -b branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/x[1].txt') -Value 'from-a' -NoNewline
    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/x[1].txt') -Value 'from-main' -NoNewline
    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/x1.txt') -Value 'unsaved' -NoNewline
    Push-Location -LiteralPath (Join-Path $repo 'sub')

    # Act
    try {
        Get-GitConflict | Resolve-GitConflict -Side Theirs
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitConflict -RepoPath $repo).Count `
        -Message 'Get-GitConflict pipes into Resolve-GitConflict from a subfolder'
    Assert-Equal -Expected 'from-a' -Actual (Get-Content -LiteralPath (Join-Path $repo 'sub/x[1].txt') -Raw) `
        -Message 'keeping the side asked for'
    Assert-Equal -Expected 'unsaved' -Actual (Get-Content -LiteralPath (Join-Path $repo 'sub/x1.txt') -Raw) `
        -Message 'and leaving alone a file the name would match as a pattern'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same kind of conflict, with Get-GitStatus objects piped in
$repo = New-GitTestRepo
try {
    git -C $repo checkout -q -b branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-a' -NoNewline
    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-main' -NoNewline
    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null

    # Act
    Get-GitStatus -RepoPath $repo | Where-Object Status -EQ 'UU' | Resolve-GitConflict -Side Ours -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitConflict -RepoPath $repo).Count `
        -Message 'A status object is bound by its Path property'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same kind of conflict, in a file named only by the PSPath of Get-Item output
$repo = New-GitTestRepo
try {
    git -C $repo checkout -q -b branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-a' -NoNewline
    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-main' -NoNewline
    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null
    $named = [PSCustomObject]@{
        PSPath = (Get-Item -LiteralPath (Join-Path $repo 'a.txt')).PSPath
    }

    # Act
    $named | Resolve-GitConflict -Side Theirs -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitConflict -RepoPath $repo).Count `
        -Message 'An object with only a PSPath is bound through the PSPath alias, and its conflict is resolved'
    Assert-Equal -Expected 'from-a' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) `
        -Message 'keeping the side asked for'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a conflict in every file, each resolved by a different form of path,
# typed from the subfolder 'sub'
$files = 'sub/dot.txt', 'sub/abs.txt', 'sub/bare.txt', 'up.txt', 'whole/w.txt'
$repo = New-GitTestPathRepo -Path $files
try {
    git -C $repo checkout -q -b branch-a 2>&1 | Out-Null
    foreach ($file in $files) {
        Set-Content -LiteralPath (Join-Path $repo $file) -Value 'from-a' -NoNewline
    }

    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    foreach ($file in $files) {
        Set-Content -LiteralPath (Join-Path $repo $file) -Value 'from-main' -NoNewline
    }

    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null
    $sub = Join-Path $repo 'sub'
    Push-Location -LiteralPath $sub

    # Act
    try {
        Resolve-GitConflict -Path '.\dot.txt' -Side Theirs
        Resolve-GitConflict -Path '..\up.txt' -Side Theirs
        Resolve-GitConflict -Path (Join-Path $sub 'abs.txt') -Side Theirs
        Resolve-GitConflict -Path 'sub/bare.txt' -Side Theirs
    }
    finally {
        Pop-Location
    }

    Resolve-GitConflict -Path '.' -Side Theirs -RepoPath (Join-Path $repo 'whole')

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitConflict -RepoPath $repo).Count `
        -Message "'.\x', '..\x', an absolute path, a bare path and '.' each resolve their conflict"
    foreach ($file in $files) {
        Assert-Equal -Expected 'from-a' -Actual (Get-Content -LiteralPath (Join-Path $repo $file) -Raw) `
            -Message "$file keeps the side asked for"
    }
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a merge that left a.txt conflicted, and an uncommitted edit to
# b.txt, which has no conflict
$repo = New-GitTestPathRepo -Path 'b.txt'
try {
    git -C $repo checkout -q -b branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-a' -NoNewline
    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-main' -NoNewline
    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'unsaved' -NoNewline

    # Act / Assert
    Assert-Throws -ScriptBlock { Resolve-GitConflict -Path 'b.txt' -Side Ours -RepoPath $repo } `
        -MessageLike "Keeping the Ours side of b.txt failed: -Path 'b.txt' has no conflict to resolve." `
        -Message 'A path with no conflict is refused'

    # Assert
    Assert-Equal -Expected 'unsaved' -Actual (Get-Content -LiteralPath (Join-Path $repo 'b.txt') -Raw) `
        -Message 'and its uncommitted edit is left alone'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder holding a conflicted file and an uncommitted edit to a file
# with no conflict, resolved as a whole
$repo = New-GitTestPathRepo -Path 'whole/w.txt', 'whole/other.txt'
try {
    git -C $repo checkout -q -b branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'whole/w.txt') -Value 'from-a' -NoNewline
    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'whole/w.txt') -Value 'from-main' -NoNewline
    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'whole/other.txt') -Value 'unsaved' -NoNewline

    # Act
    Resolve-GitConflict -Path 'whole' -Side Theirs -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitConflict -RepoPath $repo).Count `
        -Message 'A folder resolves the conflicts inside it'
    Assert-Equal -Expected 'from-a' -Actual (Get-Content -LiteralPath (Join-Path $repo 'whole/w.txt') -Raw) `
        -Message 'keeping the side asked for'
    Assert-Equal -Expected 'unsaved' -Actual (Get-Content -LiteralPath (Join-Path $repo 'whole/other.txt') -Raw) `
        -Message 'and leaves the uncommitted edit of a file with no conflict alone'
    Assert-Equal -Expected @(' M whole/other.txt') -Actual @(git -C $repo status --porcelain -- whole/other.txt) `
        -Message 'without staging it'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
