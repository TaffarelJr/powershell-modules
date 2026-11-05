#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$repo = New-GitTestRepo
$plain = New-GitTestFolder
$bare = Join-Path ([System.IO.Path]::GetTempPath()) "git-bare-$([Guid]::NewGuid())"
git init --quiet --bare $bare 2>&1 | Out-Null
New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Push-Location -LiteralPath (Join-Path $repo 'sub')

    # Act
    try {
        $omitted = & $module { Get-GitRepoLocation -Activity 'Testing' }
        $relative = & $module { Get-GitRepoLocation -Activity 'Testing' -RepoPath '.' }
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected $repo -Actual $omitted `
        -Message 'Without -RepoPath, it is the root of the repository the current location is in'
    Assert-Equal -Expected $repo -Actual $relative `
        -Message 'A relative -RepoPath is read against the current location, and gives the root'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $full = & $module { param($Path) Get-GitRepoLocation -Activity 'Testing' -RepoPath $Path } (Join-Path $repo 'sub')
    $allowed = & $module { param($Path) Get-GitRepoLocation -Activity 'Testing' -RepoPath $Path -AllowBare } $repo

    # Assert
    Assert-Equal -Expected $repo -Actual $full -Message 'A full -RepoPath in a subfolder gives the root'
    Assert-Equal -Expected $repo -Actual $allowed -Message 'With -AllowBare, a working tree still gives its root'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $bareRoot = & $module { param($Path) Get-GitRepoLocation -Activity 'Testing' -RepoPath $Path -AllowBare } $bare

    # Assert
    Assert-Equal -Expected $bare -Actual $bareRoot -Message 'With -AllowBare, a bare repository gives its own folder'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { param($Path) Get-GitRepoLocation -Activity 'Testing' -RepoPath $Path } $bare
    } -MessageLike "Testing failed: '$bare' is not inside a git working tree (*work tree*)." `
        -Message 'Without -AllowBare, a bare repository throws, with git''s reason'
    Assert-Throws -ScriptBlock {
        & $module { param($Path) Get-GitRepoLocation -Activity 'Testing' -RepoPath $Path } $plain
    } -MessageLike "Testing failed: '$plain' is not inside a git working tree (*not a git repository*)." `
        -Message 'A folder that is no repository throws, with git''s reason'
    Assert-Throws -ScriptBlock {
        & $module { param($Path) Get-GitRepoLocation -Activity 'Testing' -RepoPath $Path -AllowBare } $plain
    } -MessageLike "Testing failed: '$plain' is not inside a git repository (*not a git repository*)." `
        -Message 'With -AllowBare, the message says no repository at all'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Push-Location -LiteralPath $plain

    # Act / Assert
    try {
        Assert-Throws -ScriptBlock { & $module { Get-GitRepoLocation -Activity 'Testing' } } `
            -MessageLike 'Testing failed: the current folder is not inside a git working tree (*' `
            -Message 'Without -RepoPath, the message names the current folder'
    }
    finally {
        Pop-Location
    }
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $plain
    Remove-GitTestRepo -Path $bare
}

exit (Complete-TestRun)
