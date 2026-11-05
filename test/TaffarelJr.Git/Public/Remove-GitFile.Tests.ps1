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
    Remove-GitFile -Path 'a.txt' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'a.txt')) `
        -Message 'The file is removed from disk'
    Assert-Equal -Expected $true -Actual (Test-GitChange -Staged -RepoPath $repo) `
        -Message 'The deletion is already staged'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder with a tracked file inside it
    git -C $repo commit --quiet -m 'remove a' 2>&1 | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add sub' 2>&1 | Out-Null

    # Act / Assert - a bare file delete refuses a folder
    Assert-Throws -ScriptBlock { Remove-GitFile -Path 'sub' -RepoPath $repo } `
        -MessageLike '*Deleting sub failed*recursively without -r*' `
        -Message 'Deleting a folder without -Recurse throws'

    # Act - -Recurse deletes the whole folder
    Remove-GitFile -Path 'sub' -Recurse -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'sub')) `
        -Message '-Recurse removes the folder'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two files, removed via the pipeline
    git -C $repo commit --quiet -m 'remove sub' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'd.txt') -Value 'd' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'e.txt') -Value 'e' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add d and e' 2>&1 | Out-Null

    # Act
    @('d.txt', 'e.txt') | Remove-GitFile -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'd.txt')) `
        -Message 'The first piped file is removed'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'e.txt')) `
        -Message 'The second piped file is removed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tracked file named only by the PSPath of Get-Item output
    Set-Content -LiteralPath (Join-Path $repo 'g.txt') -Value 'g' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add g' 2>&1 | Out-Null
    $named = [PSCustomObject]@{
        PSPath = (Get-Item -LiteralPath (Join-Path $repo 'g.txt')).PSPath
    }

    # Act
    $named | Remove-GitFile -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'g.txt')) `
        -Message 'An object with only a PSPath is bound through the PSPath alias, and its file is removed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tracked file with changes that are not committed
    git -C $repo commit --quiet -m 'remove d and e' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'f.txt') -Value 'f' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add f' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'f.txt') -Value 'edited and not committed' -NoNewline

    # Act / Assert - git will not throw that work away
    Assert-Throws -ScriptBlock { Remove-GitFile -Path 'f.txt' -RepoPath $repo } -MessageLike '*f.txt*' `
        -Message 'A file with uncommitted changes is not deleted without -Force'
    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath (Join-Path $repo 'f.txt')) `
        -Message 'and it is still there'

    # Act - -Force does
    Remove-GitFile -Path 'f.txt' -Force -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'f.txt')) `
        -Message '-Force deletes it anyway'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two tracked files, one named like a pattern the other matches
    git -C $repo commit --quiet -m 'remove f' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'report[1].txt') -Value 'r' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'report1.txt') -Value 'SECRET' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add reports' 2>&1 | Out-Null

    # Act
    Remove-GitFile -Path 'report[1].txt' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'report[1].txt')) `
        -Message 'A path holding pattern characters deletes that file'
    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath (Join-Path $repo 'report1.txt')) `
        -Message 'and not another file the pattern would match'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tracked file in a subfolder, which is where PowerShell is
    git -C $repo commit --quiet -m 'remove report' 2>&1 | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repo 'deep') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'deep/g.txt') -Value 'g' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add deep' 2>&1 | Out-Null
    Push-Location -LiteralPath (Join-Path $repo 'deep')

    # Act
    try {
        Remove-GitFile -Path 'deep/g.txt'
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'deep/g.txt')) `
        -Message 'A path relative to the repository root is found from a subfolder'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - tracked files, each deleted by a different form of path, typed from
# the subfolder 'sub', and one left alone
$repo = New-GitTestPathRepo -Path 'sub/dot.txt', 'sub/abs.txt', 'sub/bare.txt', 'up.txt', 'whole/w.txt', 'outside.txt'
try {
    $sub = Join-Path $repo 'sub'
    Push-Location -LiteralPath $sub

    # Act
    try {
        Remove-GitFile -Path '.\dot.txt'
        Remove-GitFile -Path '..\up.txt'
        Remove-GitFile -Path (Join-Path $sub 'abs.txt')
        Remove-GitFile -Path 'sub/bare.txt'
    }
    finally {
        Pop-Location
    }

    Remove-GitFile -Path '.' -Recurse -RepoPath (Join-Path $repo 'whole')

    # Assert
    $status = @(Get-GitStatus -RepoPath $repo)
    $rows = @(
        @{ Path = 'sub/dot.txt'; Expected = 'D '; Form = "'.\dot.txt', relative to the current location" }
        @{ Path = 'up.txt'; Expected = 'D '; Form = "'..\up.txt', relative to the current location" }
        @{ Path = 'sub/abs.txt'; Expected = 'D '; Form = 'an absolute path' }
        @{ Path = 'sub/bare.txt'; Expected = 'D '; Form = 'a bare path, relative to the repository root' }
        @{ Path = 'whole/w.txt'; Expected = 'D '; Form = "'.', the folder -RepoPath names" }
    )
    foreach ($row in $rows) {
        $entry = @($status | Where-Object Path -EQ $row.Path)
        Assert-Equal -Expected $row.Expected -Actual $entry[0].Status `
            -Message "$($row.Path), named by $($row.Form), is deleted"
    }

    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath (Join-Path $repo 'outside.txt')) `
        -Message 'and a file no path named is kept'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
