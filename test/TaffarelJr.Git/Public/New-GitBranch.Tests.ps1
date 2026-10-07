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
    # Act - create without switching
    New-GitBranch -Name 'feature' -RepoPath $repo

    # Assert
    $branches = Get-GitBranch -List -RepoPath $repo
    Assert-That -Condition ($branches -contains 'feature') -Message 'The branch is created'
    Assert-Equal -Expected 'main' -Actual (Get-GitBranch -RepoPath $repo) -Message 'The current branch does not change'

    #───────────────────────────────────────────────────────────────────────────
    # Act - create with -Switch
    New-GitBranch -Name 'feature2' -Switch -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'feature2' -Actual (Get-GitBranch -RepoPath $repo) -Message '-Switch checks the new branch out'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a second commit on main, after branching off of the first
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'second' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'second' 2>&1 | Out-Null
    $mainTip = (git -C $repo rev-parse main).Trim()

    # Act - a branch from an explicit start point
    New-GitBranch -Name 'from-main' -StartPoint 'main' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $mainTip -Actual (Resolve-GitRef -Ref 'from-main' -RepoPath $repo) `
        -Message 'The new branch starts at the given start point'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
