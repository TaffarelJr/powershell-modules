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
    # Arrange / Act / Assert - no remotes yet
    Assert-Equal -Expected 0 -Actual @(Get-GitRemote -RepoPath $repo).Count -Message 'A fresh repo has no remotes'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    git -C $repo remote add origin 'https://example.invalid/repo.git' 2>&1 | Out-Null

    # Act - listing names
    $remotes = @(Get-GitRemote -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 1 -Actual $remotes.Count -Message 'Lists every remote by name'
    Assert-Equal -Expected 'origin' -Actual $remotes[0] -Message 'The remote name is correct'

    # Act / Assert - reading one remote's URL
    Assert-Equal -Expected 'https://example.invalid/repo.git' -Actual (Get-GitRemote -Name 'origin' -RepoPath $repo) `
        -Message '-Name returns that remote''s URL'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a remote that does not exist
    Assert-Equal -Expected $null -Actual (Get-GitRemote -Name 'nope' -RepoPath $repo) `
        -Message 'A missing remote returns $null, not a throw'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$plain = New-GitTestFolder
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Get-GitRemote -Name 'origin' -RepoPath $plain } `
        -MessageLike '*Reading the origin remote failed (exit 128)*not a git repository*' `
        -Message 'A folder that is no repository throws rather than reading as no such remote'
}
finally {
    Remove-GitTestRepo -Path $plain
}

exit (Complete-TestRun)
