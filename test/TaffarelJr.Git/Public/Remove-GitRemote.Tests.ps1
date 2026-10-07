#Requires -Version 7.0
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
    # Arrange
    git -C $repo remote add origin 'https://example.invalid/repo.git' 2>&1 | Out-Null

    # Act
    Remove-GitRemote -Name 'origin' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual (Get-GitRemote -RepoPath $repo).Count -Message 'The remote is removed'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - removing one that was never there does not throw
    Remove-GitRemote -Name 'never-existed' -RepoPath $repo
    Assert-Equal -Expected 0 -Actual (Get-GitRemote -RepoPath $repo).Count -Message 'Removing a missing remote is tolerated'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two remotes, removed via the pipeline
    git -C $repo remote add a 'https://example.invalid/a.git' 2>&1 | Out-Null
    git -C $repo remote add b 'https://example.invalid/b.git' 2>&1 | Out-Null

    # Act
    @('a', 'b') | Remove-GitRemote -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual (Get-GitRemote -RepoPath $repo).Count -Message 'Both piped remotes are removed'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
