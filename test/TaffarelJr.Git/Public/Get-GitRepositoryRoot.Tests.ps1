#Requires -Version 7.4
using namespace System.IO

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
    # Arrange / Act - the repo's own path
    $root = Get-GitRepositoryRoot -RepoPath $repo

    # Assert
    Assert-Equal -Expected ([Path]::GetFullPath($repo)) -Actual $root `
        -Message 'Returns the repo root, with the platform''s own separators'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a subfolder inside the repo
    $sub = Join-Path $repo 'sub'
    New-Item -ItemType Directory -Path $sub | Out-Null

    # Act / Assert
    Assert-Equal -Expected ([Path]::GetFullPath($repo)) -Actual (Get-GitRepositoryRoot -RepoPath $sub) `
        -Message 'A subfolder still resolves to the repo root'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - a bare repository, which has no working tree
    $bare = Join-Path ([Path]::GetTempPath()) "bare-$([Guid]::NewGuid()).git"
    git init --quiet --bare $bare 2>&1 | Out-Null

    # Assert
    try {
        Assert-Equal -Expected $null -Actual (Get-GitRepositoryRoot -RepoPath $bare) `
            -Message 'A bare repository has no root to report'
    }
    finally {
        Remove-Item -LiteralPath $bare -Recurse -Force -ErrorAction SilentlyContinue
    }

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - not a repo at all
    $plain = Join-Path ([Path]::GetTempPath()) "not-a-repo-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $plain | Out-Null

    # Assert
    try {
        Assert-Equal -Expected $null -Actual (Get-GitRepositoryRoot -RepoPath $plain) `
            -Message 'A plain folder returns $null'
    }
    finally {
        Remove-Item -LiteralPath $plain -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
