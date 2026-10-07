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
    git -C $repo branch feature 2>&1 | Out-Null

    # Act / Assert - switching to an existing branch
    Switch-GitBranch -Name 'feature' -RepoPath $repo
    Assert-Equal -Expected 'feature' -Actual (Get-GitBranch -RepoPath $repo) -Message 'Checks the branch out'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - switching to a branch that does not exist throws
    git -C $repo checkout -q main 2>&1 | Out-Null
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'nope' -RepoPath $repo } `
        -Message 'Switching to a nonexistent branch without -Create throws'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - -Create makes a new branch from a start point
    Switch-GitBranch -Name 'new-branch' -Create -StartPoint 'feature' -RepoPath $repo
    Assert-Equal -Expected 'new-branch' -Actual (Get-GitBranch -RepoPath $repo) -Message '-Create switches to the new branch'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'feature' -RepoPath $repo) -Actual (Resolve-GitRef -Ref 'new-branch' -RepoPath $repo) `
        -Message '-Create starts the branch at -StartPoint'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - -Create on an existing branch resets it (git's -B)
    git -C $repo checkout -q main 2>&1 | Out-Null
    Switch-GitBranch -Name 'new-branch' -Create -StartPoint 'main' -RepoPath $repo
    Assert-Equal -Expected (Resolve-GitRef -Ref 'main' -RepoPath $repo) -Actual (Resolve-GitRef -Ref 'new-branch' -RepoPath $repo) `
        -Message '-Create on an existing branch resets it to the new start point'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
