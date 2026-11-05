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
    # Arrange / Act / Assert - the current branch, right after init
    Assert-Equal -Expected 'main' -Actual (Get-GitBranch -RepoPath $repo) -Message 'Reports the current branch'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a second branch, checked out
    git -C $repo checkout -q -b other 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected 'other' -Actual (Get-GitBranch -RepoPath $repo) -Message 'Reflects a branch switch'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -List returns every local branch
    $branches = @(Get-GitBranch -List -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 2 -Actual $branches.Count -Message '-List returns every local branch'
    Assert-That -Condition ($branches -contains 'main') -Message '-List includes main'
    Assert-That -Condition ($branches -contains 'other') -Message '-List includes other'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tag with the same name as a branch, which makes git abbreviate
    # the branch's name to 'heads/main' when asked for its short form
    git -C $repo checkout -q main 2>&1 | Out-Null
    git -C $repo tag main 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected 'main' -Actual (Get-GitBranch -RepoPath $repo) `
        -Message 'A tag named like the branch does not change the branch''s name'
    Assert-Equal -Expected 'main, other' -Actual ((Get-GitBranch -List -RepoPath $repo) -join ', ') `
        -Message '-List names are the same plain names'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - HEAD pointed at a ref that is not a branch at all
    git -C $repo symbolic-ref HEAD refs/remotes/origin/elsewhere 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected 'refs/remotes/origin/elsewhere' -Actual (Get-GitBranch -RepoPath $repo) `
        -Message 'A HEAD that names something other than a branch is returned in full, not cut at a prefix it does not have'

    # Act
    git -C $repo symbolic-ref HEAD refs/heads/main 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a detached HEAD, which is on no branch
    git -C $repo checkout -q --detach 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected $null -Actual (Get-GitBranch -RepoPath $repo) `
        -Message 'A detached HEAD has no current branch, so $null rather than the word HEAD'
    Assert-Equal -Expected 'main, other' -Actual ((Get-GitBranch -List -RepoPath $repo) -join ', ') `
        -Message '-List leaves out the "(HEAD detached at ...)" line git branch prints'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a repository with no commits yet still has a branch
$empty = New-GitTestRepo -NoCommit

# Assert
try {
    Assert-Equal -Expected 'main' -Actual (Get-GitBranch -RepoPath $empty) `
        -Message 'A branch with no commits yet is still the current branch'
    Assert-Equal -Expected 0 -Actual @(Get-GitBranch -List -RepoPath $empty).Count `
        -Message 'but is not yet listed, since it does not exist as a ref'
}
finally {
    Remove-GitTestRepo -Path $empty
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act - a folder that is no repository
$plain = Join-Path ([System.IO.Path]::GetTempPath()) "not-a-repo-$([Guid]::NewGuid())"
New-Item -ItemType Directory -Path $plain | Out-Null

# Assert
try {
    Assert-Throws -ScriptBlock { Get-GitBranch -RepoPath $plain } `
        -MessageLike '*Reading the current branch failed (exit 128)*not a git repository*' `
        -Message 'Outside a repository it throws, rather than reading as a detached HEAD'
}
finally {
    Remove-Item -LiteralPath $plain -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
