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
    $before = (git -C $repo rev-parse HEAD).Trim()
    git -C $repo mv a.txt renamed.txt 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'rename a' 2>&1 | Out-Null
    $after = (git -C $repo rev-parse HEAD).Trim()

    # Act
    $renames = @(Get-GitRename -FromRef $before -ToRef $after -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 1 -Actual $renames.Count -Message 'The rename is detected'
    Assert-Equal -Expected 'a.txt' -Actual $renames[0].OldPath -Message 'OldPath is the original name'
    Assert-Equal -Expected 'renamed.txt' -Actual $renames[0].NewPath -Message 'NewPath is the new name'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a commit with no renames at all
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add b' 2>&1 | Out-Null

    # Act
    $none = @(Get-GitRename -FromRef $after -ToRef 'HEAD' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 0 -Actual $none.Count -Message 'A plain add reports no renames'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a rename between two names git would quote and escape
    $accentedOld = "caf$([char]0xE9) au lait.txt"
    $accentedNew = "caf$([char]0xE8) noir.txt"
    Set-Content -LiteralPath (Join-Path $repo $accentedOld) -Value 'coffee' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add accented' 2>&1 | Out-Null
    $beforeAccent = (git -C $repo rev-parse HEAD).Trim()
    git -C $repo mv $accentedOld $accentedNew 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'rename accented' 2>&1 | Out-Null

    # Act
    $accented = @(Get-GitRename -FromRef $beforeAccent -ToRef 'HEAD' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected $accentedOld -Actual $accented[0].OldPath `
        -Message 'The old path comes back as the name on disk'
    Assert-Equal -Expected $accentedNew -Actual $accented[0].NewPath -Message 'So does the new path'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two renames in one range, and a -Path scoping to one of them
    git -C $repo mv b.txt b2.txt 2>&1 | Out-Null
    git -C $repo mv renamed.txt renamed2.txt 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'rename two' 2>&1 | Out-Null

    # Act
    $two = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -RepoPath $repo)
    $scoped = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path 'b2.txt' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 2 -Actual $two.Count -Message 'Every rename in the range is returned'
    Assert-Equal -Expected 1 -Actual $scoped.Count -Message '-Path scopes the comparison to one path'
    Assert-Equal -Expected 'b.txt' -Actual $scoped[0].OldPath -Message 'and it is the right rename'

    #───────────────────────────────────────────────────────────────────────────
    # Act - the same rename, found from its old name, and one that matches nothing
    $byOldName = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path 'b.txt' -RepoPath $repo)
    $byNothing = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path 'unrelated.txt' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 'b2.txt' -Actual $byOldName[0].NewPath `
        -Message '-Path finds a rename from the name it started at'
    Assert-Equal -Expected 0 -Actual $byNothing.Count -Message 'and returns nothing for a path no rename touches'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a rename inside a folder
    New-Item -ItemType Directory -Path (Join-Path $repo 'docs') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'docs' 'one.md') -Value 'docs page' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add docs page' 2>&1 | Out-Null
    git -C $repo mv 'docs/one.md' 'docs/two.md' 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'rename docs page' 2>&1 | Out-Null

    # Act
    $inFolder = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path 'docs' -RepoPath $repo)
    $inFolderSlash = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path 'docs/' -RepoPath $repo)
    $lookalike = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path 'doc' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 1 -Actual $inFolder.Count -Message 'A folder as -Path keeps the renames inside it'
    Assert-Equal -Expected 1 -Actual $inFolderSlash.Count -Message 'with or without a trailing slash'
    Assert-Equal -Expected 0 -Actual $lookalike.Count -Message 'but not a folder whose name only starts the same way'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $wrongCaseFile = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path 'DOCS/one.md' -RepoPath $repo)
    $wrongCaseFolder = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path 'Docs' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 0 -Actual $wrongCaseFile.Count `
        -Message 'A path in another case is another path, as git names them'
    Assert-Equal -Expected 0 -Actual $wrongCaseFolder.Count -Message 'and so is a folder'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a branch named like a tracked folder, before the rename
    git -C $repo branch docs HEAD~1 2>&1 | Out-Null

    # Act
    $byBranch = @(Get-GitRename -FromRef 'docs' -ToRef 'HEAD' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 'docs/two.md' -Actual $byBranch[0].NewPath `
        -Message 'A ref named like a folder is read as the ref'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one rename inside the subfolder 'sub' and one outside it, read by
# every form of path from inside it
$repo = New-GitTestRepo
$sub = Join-Path $repo 'sub'
New-Item -ItemType Directory -Path $sub | Out-Null
Set-Content -LiteralPath (Join-Path $sub 'x.txt') -Value 'inside the subfolder' -NoNewline
Set-Content -LiteralPath (Join-Path $repo 'up.txt') -Value 'outside the subfolder' -NoNewline
git -C $repo add -A 2>&1 | Out-Null
git -C $repo commit --quiet -m 'add files' 2>&1 | Out-Null
git -C $repo mv sub/x.txt sub/y.txt 2>&1 | Out-Null
git -C $repo mv up.txt up2.txt 2>&1 | Out-Null
git -C $repo commit --quiet -m 'rename both' 2>&1 | Out-Null
$rows = @(
    @{ Path = '.\y.txt'; Expected = 'sub/y.txt'; Form = "'.\y.txt', relative to the current location" }
    @{ Path = '..\up.txt'; Expected = 'up2.txt'; Form = "'..\up.txt', relative to the current location" }
    @{ Path = (Join-Path $sub 'x.txt'); Expected = 'sub/y.txt'; Form = 'an absolute path' }
    @{ Path = 'sub'; Expected = 'sub/y.txt'; Form = 'a bare path, relative to the repository root' }
    @{ Path = '.'; Expected = 'sub/y.txt'; Form = "'.', the current folder" }
    @{ Path = '..'; Expected = 'sub/y.txt, up2.txt'; Form = "'..', the whole repository" }
    @{ Path = 'sub/./y.txt'; Expected = 'sub/y.txt'; Form = "a bare path with an inner '.'" }
    @{ Path = 'sub/../up2.txt'; Expected = 'up2.txt'; Form = "a bare path with an inner '..'" }
)
Push-Location -LiteralPath $sub

# Act / Assert
try {
    foreach ($row in $rows) {
        $renames = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path $row.Path)
        Assert-Equal -Expected $row.Expected -Actual ($renames.ForEach('NewPath') -join ', ') `
            -Message "$($row.Form) keeps the renames where it points"
    }

    Assert-Throws -ScriptBlock { Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path '..\..' } `
        -MessageLike "*Reading renames failed: -Path '..\..' is outside the repository at '*'.*" `
        -Message 'A path outside the repository throws rather than matching nothing'
    Assert-Throws -ScriptBlock { Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path '/' } `
        -MessageLike "*Reading renames failed: -Path '/' is outside the repository at '*'.*" `
        -Message "'/' is the root of a drive or file system, not the whole repository"
    Assert-Throws -ScriptBlock { Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path 'sub/../../x' } `
        -MessageLike "Reading renames failed: -Path 'sub/../../x' climbs above the repository root.*" `
            -Message 'A bare path that climbs above the root throws'
}
finally {
    Pop-Location
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a junction (a symbolic link where there are no junctions) to the
# repository, and paths through it
$link = Join-Path ([System.IO.Path]::GetTempPath()) "git-link-$([Guid]::NewGuid())"
$linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
New-Item -ItemType $linkType -Path $link -Target $repo | Out-Null

# Act
try {
    $throughLink = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path (Join-Path $link 'sub' 'x.txt') -RepoPath $repo)
    $fromLink = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path '.\sub' -RepoPath $link)
}
finally {
    [System.IO.Directory]::Delete($link)
}

# Assert
Assert-Equal -Expected 'sub/y.txt' -Actual ($throughLink.ForEach('NewPath') -join ', ') `
    -Message 'An absolute path through a link is inside the repository'
Assert-Equal -Expected 'sub/y.txt' -Actual ($fromLink.ForEach('NewPath') -join ', ') `
    -Message 'and so is a dot path from a -RepoPath that is a link'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare clone, which has no working tree for a path to be in
$bare = Join-Path ([System.IO.Path]::GetTempPath()) "bare-$([Guid]::NewGuid()).git"
git clone --quiet --bare $repo $bare 2>&1 | Out-Null
try {
    # Act
    $bareRenames = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path 'sub' -RepoPath $bare)

    # Assert
    Assert-Equal -Expected 'sub/y.txt' -Actual ($bareRenames.ForEach('NewPath') -join ', ') `
        -Message 'A bare path needs no working tree'
    Assert-Throws -ScriptBlock { Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path '.' -RepoPath $bare } `
        -MessageLike "*Reading renames failed: -Path '.' needs a working tree*relative to the repository root.*" `
        -Message 'but a path starting with a dot does, and its absence is said'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the bare clone and a separate working tree, selected only by
    # GIT_DIR and GIT_WORK_TREE, as a dotfiles repository or a hook does
    $workTree = New-GitTestFolder
    New-Item -ItemType Directory -Path (Join-Path $workTree 'sub') | Out-Null
    Push-Location -LiteralPath $workTree
    $env:GIT_DIR = $bare
    $env:GIT_WORK_TREE = $workTree

    # Act
    try {
        $byVariables = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path '.\sub')
    }
    finally {
        Remove-Item -LiteralPath Env:GIT_DIR, Env:GIT_WORK_TREE
        Pop-Location
        Remove-GitTestRepo -Path $workTree
    }

    # Assert
    Assert-Equal -Expected 'sub/y.txt' -Actual ($byVariables.ForEach('NewPath') -join ', ') `
        -Message 'Without -RepoPath, a dot path is read in the repository GIT_DIR and GIT_WORK_TREE select'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a relative GIT_DIR, as 'git --git-dir=.git' hands a hook
    Push-Location -LiteralPath $repo
    $env:GIT_DIR = '.git'

    # Act
    try {
        $relativeDot = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path '.\sub')
        $relativeAbsolute = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path (Join-Path $repo 'sub'))
    }
    finally {
        Remove-Item -LiteralPath Env:GIT_DIR
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected 'sub/y.txt' -Actual ($relativeDot.ForEach('NewPath') -join ', ') `
        -Message 'A relative GIT_DIR is read where the call runs, for a dot path'
    Assert-Equal -Expected 'sub/y.txt' -Actual ($relativeAbsolute.ForEach('NewPath') -join ', ') `
        -Message 'and for an absolute one'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a linked worktree, with only GIT_DIR set, as git sets it for a
    # hook run there
    $linked = Join-Path ([System.IO.Path]::GetTempPath()) "git-wt-$([Guid]::NewGuid())"
    git -C $repo worktree add --quiet --detach $linked 2>&1 | Out-Null
    $linkedGitDir = (git -C $linked rev-parse --absolute-git-dir) -join ''
    Push-Location -LiteralPath $linked
    $env:GIT_DIR = $linkedGitDir

    # Act
    try {
        $linkedDot = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path '.\sub')
        $linkedAbsolute = @(Get-GitRename -FromRef 'HEAD~1' -ToRef 'HEAD' -Path (Join-Path $linked 'sub'))
    }
    finally {
        Remove-Item -LiteralPath Env:GIT_DIR
        Pop-Location
        git -C $repo worktree remove --force $linked 2>&1 | Out-Null
        Remove-GitTestRepo -Path $linked
    }

    # Assert
    Assert-Equal -Expected 'sub/y.txt' -Actual ($linkedDot.ForEach('NewPath') -join ', ') `
        -Message 'In a linked worktree with only GIT_DIR set, a dot path is inside the repository'
    Assert-Equal -Expected 'sub/y.txt' -Actual ($linkedAbsolute.ForEach('NewPath') -join ', ') `
        -Message 'and so is an absolute one'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $bare
}

exit (Complete-TestRun)
