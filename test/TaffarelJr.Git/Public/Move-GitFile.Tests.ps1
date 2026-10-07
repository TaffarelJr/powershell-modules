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
    # Act
    Move-GitFile -Path 'a.txt' -Destination 'renamed.txt' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'a.txt')) `
        -Message 'The old path no longer exists on disk'
    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath (Join-Path $repo 'renamed.txt')) `
        -Message 'The new path exists on disk'
    Assert-Equal -Expected $true -Actual (Test-GitChange -Staged -RepoPath $repo) `
        -Message 'The rename is already staged'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a destination that already exists
    git -C $repo commit --quiet -m 'rename' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'taken.txt') -Value 'existing' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add taken' 2>&1 | Out-Null

    # Act / Assert - refused without -Force
    Assert-Throws -ScriptBlock { Move-GitFile -Path 'renamed.txt' -Destination 'taken.txt' -RepoPath $repo } `
        -MessageLike '*Renaming renamed.txt failed*destination exists*' `
            -Message 'Moving onto an existing path is refused without -Force'

    # Act - -Force overwrites it
    Move-GitFile -Path 'renamed.txt' -Destination 'taken.txt' -Force -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'renamed.txt')) `
        -Message '-Force completes the move'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file whose name starts with a dash
    Set-Content -LiteralPath (Join-Path $repo '-odd.txt') -Value 'odd' -NoNewline
    git -C $repo add -- '-odd.txt' 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add odd' 2>&1 | Out-Null

    # Act
    Move-GitFile -Path '-odd.txt' -Destination '-even.txt' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath (Join-Path $repo '-even.txt')) `
        -Message 'A path starting with a dash is a path, not an option'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tracked file named with pattern characters, moved from a
    # subfolder by paths relative to the repository root
    Set-Content -LiteralPath (Join-Path $repo 'report[1].txt') -Value 'r' -NoNewline
    New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/keep.txt') -Value 'k' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add report' 2>&1 | Out-Null
    Push-Location -LiteralPath (Join-Path $repo 'sub')

    # Act
    try {
        Move-GitFile -Path 'report[1].txt' -Destination 'sub\moved[1].txt'
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath (Join-Path $repo 'sub/moved[1].txt')) `
        -Message 'Both paths are relative to the repository root, whichever folder the call runs in'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'report[1].txt')) `
        -Message 'and the file has left its old path'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$plain = New-GitTestFolder
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Move-GitFile -Path 'a.txt' -Destination 'b.txt' -RepoPath $plain } `
        -MessageLike "*Renaming a.txt failed: '*' is not inside a git working tree*" `
            -Message 'Outside a working tree it says so'
}
finally {
    Remove-GitTestRepo -Path $plain
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - tracked files, each moved by a different form of path, typed from
# the subfolder 'sub'
$repo = New-GitTestPathRepo -Path 'sub/dot.txt', 'sub/abs.txt', 'sub/bare.txt', 'up.txt', 'whole/w.txt'
try {
    $sub = Join-Path $repo 'sub'
    Push-Location -LiteralPath $sub

    # Act
    try {
        Move-GitFile -Path '.\dot.txt' -Destination '.\dot-moved.txt'
        Move-GitFile -Path '..\up.txt' -Destination '..\up-moved.txt'
        Move-GitFile -Path (Join-Path $sub 'abs.txt') -Destination (Join-Path $sub 'abs-moved.txt')
        Move-GitFile -Path 'sub/bare.txt' -Destination 'sub/bare-moved.txt'
    }
    finally {
        Pop-Location
    }

    Move-GitFile -Path '.' -Destination '..\whole-moved' -RepoPath (Join-Path $repo 'whole')

    # Assert
    $status = @(Get-GitStatus -RepoPath $repo)
    $rows = @(
        @{ Path = 'sub/dot-moved.txt'; Form = "'.\x', relative to the current location" }
        @{ Path = 'up-moved.txt'; Form = "'..\x', relative to the current location" }
        @{ Path = 'sub/abs-moved.txt'; Form = 'an absolute path' }
        @{ Path = 'sub/bare-moved.txt'; Form = 'a bare path, relative to the repository root' }
        @{ Path = 'whole-moved/w.txt'; Form = "'.', the folder -RepoPath names" }
    )
    foreach ($row in $rows) {
        $entry = @($status | Where-Object Path -EQ $row.Path)
        Assert-Equal -Expected 'R ' -Actual $entry[0].Status `
            -Message "$($row.Path) is a staged rename, moved by $($row.Form)"
    }
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a temporary index, as a git hook has, named only by GIT_INDEX_FILE;
# PowerShell is in the repository and no -RepoPath is given
$repo = New-GitTestRepo
$index = Join-Path ([System.IO.Path]::GetTempPath()) "git-index-$([Guid]::NewGuid())"
Copy-Item -LiteralPath (Join-Path $repo '.git/index') -Destination $index
Push-Location -LiteralPath $repo
$env:GIT_INDEX_FILE = $index

# Act
try {
    Move-GitFile -Path 'a.txt' -Destination 'b.txt'
    $inTemporary = (git -C $repo ls-files) -join ', '
}
finally {
    Remove-Item -LiteralPath Env:GIT_INDEX_FILE
    Pop-Location
}

$inOwn = (git -C $repo ls-files) -join ', '

# Assert
try {
    Assert-Equal -Expected 'b.txt' -Actual $inTemporary `
        -Message 'Without -RepoPath, the index GIT_INDEX_FILE names records the rename'
    Assert-Equal -Expected 'a.txt' -Actual $inOwn -Message 'and the repository''s own index is left alone'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-Item -LiteralPath $index -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
