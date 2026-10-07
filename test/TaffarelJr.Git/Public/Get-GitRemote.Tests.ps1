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
    # Arrange / Act / Assert - no remotes yet
    Assert-Equal -Expected 0 -Actual (Get-GitRemote -RepoPath $repo).Count -Message 'A fresh repo has no remotes'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    git -C $repo remote add origin 'https://example.invalid/repo.git' 2>&1 | Out-Null

    # Act / Assert - listing names
    $remotes = Get-GitRemote -RepoPath $repo
    Assert-Equal -Expected 1 -Actual $remotes.Count -Message 'Lists every remote by name'
    Assert-Equal -Expected 'origin' -Actual $remotes[0] -Message 'The remote name is correct'

    # Act / Assert - reading one remote's URL
    Assert-Equal -Expected 'https://example.invalid/repo.git' -Actual (Get-GitRemote -Name 'origin' -RepoPath $repo) `
        -Message '-Name returns that remote''s URL'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a remote that does not exist
    Assert-Equal -Expected $null -Actual (Get-GitRemote -Name 'nope' -RepoPath $repo) -Message 'A missing remote returns $null, not a throw'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
