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

$upstream = New-GitTestRepo
$repo = New-GitTestRepo -NoCommit
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-GitRemote -Name 'origin' -Url $upstream -RepoPath $repo

    # Act
    Sync-GitRemote -Name 'origin' -RepoPath $repo

    # Assert
    Assert-That -Condition ($null -ne (Resolve-GitRef -Ref 'origin/main' -RepoPath $repo)) `
        -Message 'Fetches the remote branch'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a new commit upstream, and a tag
    Set-Content -LiteralPath (Join-Path $upstream 'b.txt') -Value 'more' -NoNewline
    git -C $upstream add -A 2>&1 | Out-Null
    git -C $upstream commit --quiet -m 'second' 2>&1 | Out-Null
    git -C $upstream tag v1.0.0 2>&1 | Out-Null

    # Act - a refspec-scoped fetch with tags
    Sync-GitRemote -Name 'origin' -Refspec 'main' -Tags -RepoPath $repo

    # Assert
    Assert-Equal -Expected (Resolve-GitRef -Ref 'main' -RepoPath $upstream) `
        -Actual (Resolve-GitRef -Ref 'origin/main' -RepoPath $repo) `
        -Message 'The remote-tracking branch advances to the new commit'
    Assert-That -Condition ($null -ne (Resolve-GitRef -Ref 'v1.0.0' -RepoPath $repo)) `
        -Message '-Tags also fetches the new tag'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - another new commit upstream
    git -C $upstream commit --quiet --allow-empty -m 'third' 2>&1 | Out-Null

    # Act - the remote named by its alias
    Sync-GitRemote -Remote 'origin' -RepoPath $repo

    # Assert
    Assert-Equal -Expected (Resolve-GitRef -Ref 'main' -RepoPath $upstream) `
        -Actual (Resolve-GitRef -Ref 'origin/main' -RepoPath $repo) `
        -Message '-Remote names the remote, as everywhere else in the module'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a second remote, and a branch deleted upstream
    $other = New-GitTestRepo
    Set-GitRemote -Name 'other' -Url $other -RepoPath $repo
    git -C $upstream branch doomed 2>&1 | Out-Null
    Sync-GitRemote -Name 'origin' -RepoPath $repo
    git -C $upstream branch -D doomed 2>&1 | Out-Null

    # Act - every remote at once, pruning
    Sync-GitRemote -All -Prune -RepoPath $repo

    # Assert
    Assert-That -Condition ($null -ne (Resolve-GitRef -Ref 'other/main' -RepoPath $repo)) `
        -Message '-All fetches every configured remote'
    Assert-Equal -Expected $null -Actual (Resolve-GitRef -Ref 'origin/doomed' -RepoPath $repo) `
        -Message '-Prune drops the tracking ref of a branch deleted upstream'
    Remove-GitTestRepo -Path $other

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - one remote and every remote cannot both be meant
    Assert-Throws -ScriptBlock {
        Sync-GitRemote -All -Refspec 'main' -RepoPath $repo
    } -MessageLike '*Parameter set cannot be resolved*' `
        -Message '-All with -Refspec is refused instead of the refspec being ignored'
    Assert-Throws -ScriptBlock {
        Sync-GitRemote -All -Name 'origin' -RepoPath $repo
    } -MessageLike '*Parameter set cannot be resolved*' -Message '-All with -Name is refused too'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a remote that is not there fails without waiting on anyone
    Assert-Throws -ScriptBlock {
        Sync-GitRemote -Name 'no-such-remote' -RepoPath $repo
    } -MessageLike '*Fetching failed*' -Message 'A missing remote throws, with git''s message'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
