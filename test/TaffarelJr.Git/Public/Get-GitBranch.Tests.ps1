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
    # Arrange / Act / Assert - the current branch, right after init
    Assert-Equal -Expected 'main' -Actual (Get-GitBranch -RepoPath $repo) -Message 'Reports the current branch'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a second branch, checked out
    git -C $repo checkout -q -b other 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected 'other' -Actual (Get-GitBranch -RepoPath $repo) -Message 'Reflects a branch switch'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - -List returns every local branch
    $branches = Get-GitBranch -List -RepoPath $repo
    Assert-Equal -Expected 2 -Actual $branches.Count -Message '-List returns every local branch'
    Assert-That -Condition ($branches -contains 'main') -Message '-List includes main'
    Assert-That -Condition ($branches -contains 'other') -Message '-List includes other'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
