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
    Assert-Equal -Expected 1 -Actual @(Get-GitRemote -RepoPath $repo).Count `
        -Message 'Repointing does not create a duplicate remote'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a name that differs from an existing remote only in case
    Set-GitRemote -Name 'Origin' -Url 'https://example.invalid/three.git' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 2 -Actual @(Get-GitRemote -RepoPath $repo).Count `
        -Message 'Remote names are case-sensitive: Origin is a new remote, not origin repointed'
    Assert-Equal -Expected 'https://example.invalid/two.git' -Actual (Get-GitRemote -Name 'origin' -RepoPath $repo) `
        -Message 'and origin is untouched'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a URL git would read as an option
    Assert-Throws -ScriptBlock {
        Set-GitRemote -Name 'evil' -Url '--upload-pack=echo-not-run' -RepoPath $repo
    } -MessageLike "*starts with '-'*" -Message 'A URL starting with a dash is refused'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
