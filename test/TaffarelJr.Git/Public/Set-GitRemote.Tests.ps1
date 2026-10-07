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
    # Act - adding a new remote
    Set-GitRemote -Name 'origin' -Url 'https://example.invalid/one.git' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'https://example.invalid/one.git' -Actual (Get-GitRemote -Name 'origin' -RepoPath $repo) `
        -Message 'Adds a remote that did not exist yet'

    #───────────────────────────────────────────────────────────────────────────
    # Act - repointing an existing remote
    Set-GitRemote -Name 'origin' -Url 'https://example.invalid/two.git' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'https://example.invalid/two.git' -Actual (Get-GitRemote -Name 'origin' -RepoPath $repo) `
        -Message 'Repoints an existing remote instead of erroring'
    Assert-Equal -Expected 1 -Actual (Get-GitRemote -RepoPath $repo).Count -Message 'Repointing does not create a duplicate remote'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
