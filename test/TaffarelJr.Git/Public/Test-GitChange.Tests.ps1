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
    # Arrange / Act / Assert - nothing staged yet
    Assert-Equal -Expected $false -Actual (Test-GitChange -Staged -RepoPath $repo) `
        -Message 'Nothing staged reports false'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null

    # Act / Assert - the default parameter set is staged
    Assert-Equal -Expected $true -Actual (Test-GitChange -RepoPath $repo) -Message 'The default checks staged changes'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    git -C $repo commit --quiet -m 'change a' 2>&1 | Out-Null
    $before = (git -C $repo rev-parse HEAD~1).Trim()
    $after = (git -C $repo rev-parse HEAD).Trim()

    # Act / Assert - a path that changed between two refs
    Assert-Equal -Expected $true -Actual (Test-GitChange -FromRef $before -ToRef $after -Path 'a.txt' -RepoPath $repo) `
        -Message 'A path that changed between two refs reports true'

    # Act - a path that did not change between the same two refs
    Set-Content -LiteralPath (Join-Path $repo 'untouched.txt') -Value 'x' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add untouched' 2>&1 | Out-Null

    # Assert
    Assert-Equal -Expected $false -Actual (Test-GitChange -FromRef $after -ToRef 'HEAD' -Path 'a.txt' -RepoPath $repo) `
        -Message 'An unrelated path between two refs reports false'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a ref that does not exist is an error, not "changed"
    Assert-Throws -ScriptBlock {
        Test-GitChange -FromRef 'no-such-ref' -ToRef 'HEAD' -RepoPath $repo
    } -MessageLike '*Checking for changes failed*' -Message 'A bad ref throws instead of answering $true'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a file named with pattern characters changed in a subfolder,
    # which is where PowerShell is, next to an unchanged lookalike
    New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/r[1].txt') -Value 'r' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'sub/r1.txt') -Value 'r' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add r files' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/r1.txt') -Value 'changed' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    Push-Location -LiteralPath (Join-Path $repo 'sub')

    # Act
    try {
        $literal = Test-GitChange -Path 'sub/r[1].txt'
        $lookalike = Test-GitChange -Path 'sub/r1.txt'
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected $false -Actual $literal -Message '-Path is literal: the bracketed file has no staged change'
    Assert-Equal -Expected $true -Actual $lookalike `
        -Message 'and a path relative to the repository root works from a subfolder'
    git -C $repo commit --quiet -m 'change r1' 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a branch named like a tracked folder
    git -C $repo branch sub HEAD~1 2>&1 | Out-Null

    # Act
    $byBranch = Test-GitChange -FromRef 'sub' -ToRef 'main' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $byBranch -Message 'A ref named like a folder is read as the ref'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Test-GitChange -Staged:$false -RepoPath $repo } `
        -MessageLike 'Checking for changes failed: -Staged:$false is not supported*-FromRef and -ToRef*' `
            -Message '-Staged:$false is refused rather than checking staged changes anyway'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder that is no repository, and a bare repository
$plain = New-GitTestFolder
$bare = Join-Path ([System.IO.Path]::GetTempPath()) "bare-$([Guid]::NewGuid()).git"
git init --quiet --bare $bare 2>&1 | Out-Null
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Test-GitChange -RepoPath $plain } `
        -MessageLike "*Checking for changes failed: '*' is not inside a git working tree*" `
            -Message 'Outside a repository it says so, in one line'
    Assert-Throws -ScriptBlock { Test-GitChange -FromRef 'a' -ToRef 'b' -RepoPath $plain } `
        -MessageLike "*Checking for changes failed: '*' is not inside a git repository*" `
            -Message 'rather than comparing two files named like the refs'
    Assert-Throws -ScriptBlock { Test-GitChange -RepoPath $bare } `
        -MessageLike '*not inside a git working tree*' `
            -Message 'A bare repository has nothing staged to check, rather than always "changed"'
}
finally {
    Remove-GitTestRepo -Path $plain
    Remove-GitTestRepo -Path $bare
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - staged edits in and outside the subfolder 'sub', next to an
# unchanged file, checked by every form of path from inside it
$repo = New-GitTestPathRepo -Path 'sub/x.txt', 'sub/clean.txt', 'up.txt'
$sub = Join-Path $repo 'sub'
Set-Content -LiteralPath (Join-Path $sub 'x.txt') -Value 'edited' -NoNewline
Set-Content -LiteralPath (Join-Path $repo 'up.txt') -Value 'edited' -NoNewline
git -C $repo add -A 2>&1 | Out-Null
$rows = @(
    @{ Path = '.\x.txt'; Expected = $true; Form = "'.\x.txt', relative to the current location" }
    @{ Path = '..\up.txt'; Expected = $true; Form = "'..\up.txt', relative to the current location" }
    @{ Path = (Join-Path $sub 'x.txt'); Expected = $true; Form = 'an absolute path' }
    @{ Path = 'sub/x.txt'; Expected = $true; Form = 'a bare path, relative to the repository root' }
    @{ Path = 'sub/./x.txt'; Expected = $true; Form = 'a bare path with an inner ''.''' }
    @{ Path = 'sub/../up.txt'; Expected = $true; Form = 'a bare path with an inner ''..''' }
    @{ Path = '.'; Expected = $true; Form = "'.', the current folder" }
    @{ Path = '.\clean.txt'; Expected = $false; Form = "'.\clean.txt', which has no change" }
)
Push-Location -LiteralPath $sub

# Act / Assert
try {
    foreach ($row in $rows) {
        Assert-Equal -Expected $row.Expected -Actual (Test-GitChange -Staged -Path $row.Path) `
            -Message "$($row.Form) is checked where it points"
    }
}
finally {
    Pop-Location
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
