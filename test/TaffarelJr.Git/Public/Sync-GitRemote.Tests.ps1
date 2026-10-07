#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$upstream = New-GitTestRepo
$repo = New-GitTestRepo -NoCommit
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-GitRemote -Name 'origin' -Url $upstream -RepoPath $repo

    # Act
    Sync-GitRemote -Name 'origin' -RepoPath $repo

    # Assert
    Assert-That -Condition ($null -ne (Resolve-GitRef -Ref 'origin/main' -RepoPath $repo)) -Message 'Fetches the remote branch'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a new commit upstream, and a tag
    Set-Content -LiteralPath (Join-Path $upstream 'b.txt') -Value 'more' -NoNewline
    git -C $upstream add -A 2>&1 | Out-Null
    git -C $upstream commit --quiet -m 'second' 2>&1 | Out-Null
    git -C $upstream tag v1.0.0 2>&1 | Out-Null

    # Act - a refspec-scoped fetch with tags
    Sync-GitRemote -Name 'origin' -Refspec 'main' -Tags -RepoPath $repo

    # Assert
    Assert-Equal -Expected (Resolve-GitRef -Ref 'main' -RepoPath $upstream) -Actual (Resolve-GitRef -Ref 'origin/main' -RepoPath $repo) `
        -Message 'The remote-tracking branch advances to the new commit'
    Assert-That -Condition ($null -ne (Resolve-GitRef -Ref 'v1.0.0' -RepoPath $repo)) -Message '-Tags also fetches the new tag'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
