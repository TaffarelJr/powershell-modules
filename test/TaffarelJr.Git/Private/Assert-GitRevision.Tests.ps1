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

$repo = New-GitTestRepo
try {
    git -C $repo tag -a annotated -m 'note' 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $commit = & $module { param($Repo) Assert-GitRevision -Revision 'main' -Activity 'Testing' -RepoPath $Repo } $repo
    $tag = & $module { param($Repo) Assert-GitRevision -Revision 'annotated' -Activity 'Testing' -RepoPath $Repo } $repo
    $tree = & $module {
        param($Repo)
        Assert-GitRevision -Revision 'HEAD^{tree}' -Activity 'Testing' -AnyObject -RepoPath $Repo
    } $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @($commit).Count -Message 'A branch that names a commit passes, returning nothing'
    Assert-Equal -Expected 0 -Actual @($tag).Count -Message 'so does an annotated tag, which leads to a commit'
    Assert-Equal -Expected 0 -Actual @($tree).Count -Message 'and with -AnyObject, a tree'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock {
        & $module { param($Repo) Assert-GitRevision -Revision 'nope' -Activity 'Testing' -RepoPath $Repo } $repo
    } -MessageLike "Testing failed: 'nope' does not name a commit." -Message 'A revision that names nothing throws'
    Assert-Throws -ScriptBlock {
        & $module { param($Repo) Assert-GitRevision -Revision 'HEAD^{tree}' -Activity 'Testing' -RepoPath $Repo } $repo
    } -MessageLike "Testing failed: 'HEAD^{tree}' does not name a commit." `
        -Message 'and so does a tree, without -AnyObject'
    Assert-Throws -ScriptBlock {
        & $module {
            param($Repo)
            Assert-GitRevision -Revision 'nope' -Activity 'Testing' -AnyObject -RepoPath $Repo
        } $repo
    } -MessageLike "Testing failed: 'nope' does not name a revision." `
        -Message 'With -AnyObject, the message says no revision at all'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
