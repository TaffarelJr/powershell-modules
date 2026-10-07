#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$repo = New-GitTestRepo
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - the repo's own path
    $root = Get-GitRepositoryRoot -RepoPath $repo
    Assert-Equal -Expected ($repo -replace '\\', '/') -Actual $root -Message 'Returns the repo root, forward-slashed like git itself'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a subfolder inside the repo
    $sub = Join-Path $repo 'sub'
    New-Item -ItemType Directory -Path $sub | Out-Null

    # Act / Assert
    Assert-Equal -Expected ($repo -replace '\\', '/') -Actual (Get-GitRepositoryRoot -RepoPath $sub) `
        -Message 'A subfolder still resolves to the repo root'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - not a repo at all
    $plain = Join-Path ([Path]::GetTempPath()) "not-a-repo-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $plain | Out-Null
    try {
        Assert-Equal -Expected $null -Actual (Get-GitRepositoryRoot -RepoPath $plain) -Message 'A plain folder returns $null'
    }
    finally {
        Remove-Item -LiteralPath $plain -Recurse -Force -ErrorAction SilentlyContinue
    }
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
