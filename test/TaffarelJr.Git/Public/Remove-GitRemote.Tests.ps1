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
    git -C $repo remote add origin 'https://example.invalid/repo.git' 2>&1 | Out-Null

    Remove-GitRemote -Name 'origin' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitRemote -RepoPath $repo).Count -Message 'The remote is removed'

    #───────────────────────────────────────────────────────────────────────────
    # Act - removing one that was never there does not throw
    Remove-GitRemote -Name 'never-existed' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitRemote -RepoPath $repo).Count `
        -Message 'Removing a missing remote is tolerated'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two remotes, removed via the pipeline
    git -C $repo remote add a 'https://example.invalid/a.git' 2>&1 | Out-Null
    git -C $repo remote add b 'https://example.invalid/b.git' 2>&1 | Out-Null

    # Act
    @('a', 'b') | Remove-GitRemote -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitRemote -RepoPath $repo).Count -Message 'Both piped remotes are removed'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a remote whose name differs only in case from the one asked for
    git -C $repo remote add origin 'https://example.invalid/repo.git' 2>&1 | Out-Null

    Remove-GitRemote -Name 'Origin' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 1 -Actual @(Get-GitRemote -RepoPath $repo).Count `
        -Message 'Remote names are case-sensitive: Origin is not origin'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - only a missing remote is tolerated: a folder that is
# no repository is an error, not "nothing to remove"
$plain = Join-Path ([System.IO.Path]::GetTempPath()) "not-a-repo-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $plain | Out-Null

# Assert
try {
    Assert-Throws -ScriptBlock {
        Remove-GitRemote -Name 'origin' -RepoPath $plain
    } -MessageLike '*Listing remotes failed*not a git repository*' `
        -Message 'Outside a repository it throws instead of quietly doing nothing'
}
finally {
    Remove-Item -LiteralPath $plain -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
