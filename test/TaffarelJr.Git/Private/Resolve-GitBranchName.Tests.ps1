#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$upstream = New-GitTestRepo
git -C $upstream branch remote-only 2>&1 | Out-Null
$repo = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
git clone --quiet $upstream $repo 2>&1 | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tag named like the branch, on the same repository
    git -C $repo tag main 2>&1 | Out-Null

    # Act
    $plain = & $module { param($r) Resolve-GitBranchName -Name 'main' -Activity 'Reading' -RepoPath $r } $repo
    $full = & $module { param($r) Resolve-GitBranchName -Name 'refs/heads/main' -Activity 'Reading' -RepoPath $r } $repo

    # Assert
    Assert-Equal -Expected 'main' -Actual $plain -Message 'A branch name comes back as it is, though a tag shares it'
    Assert-Equal -Expected 'main' -Actual $full -Message 'A full refs/heads/ name comes back short'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { param($r) Resolve-GitBranchName -Name 'origin/remote-only' -Activity 'Reading' -Hint 'Do this.' -RepoPath $r } $repo
    } -MessageLike "Reading failed: there is no branch named 'origin/remote-only' ('origin/remote-only' is refs/remotes/origin/remote-only). Do this." `
        -Message 'A remote branch is no local branch; the message says what it is, then the hint'
    Assert-Throws -ScriptBlock {
        & $module { param($r) Resolve-GitBranchName -Name 'nope' -Activity 'Reading' -RepoPath $r } $repo
    } -MessageLike "Reading failed: there is no branch named 'nope'." `
        -Message 'A name that is nothing at all says only that'
    Assert-Throws -ScriptBlock {
        & $module { param($r) Resolve-GitBranchName -Name 'origin/remote-only..HEAD' -Activity 'Reading' -RepoPath $r } $repo
    } -MessageLike "Reading failed: there is no branch named 'origin/remote-only..HEAD' ('origin/remote-only..HEAD' names more than one revision)." `
        -Message 'A range is no branch, though one of its ends is'
    Assert-Throws -ScriptBlock {
        & $module { param($r) Resolve-GitBranchName -Name 'HEAD^!' -Activity 'Reading' -RepoPath $r } $repo
    } -MessageLike "Reading failed: there is no branch named 'HEAD^!'." `
        -Message 'A form git refuses to verify is no branch, though git printed one'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
