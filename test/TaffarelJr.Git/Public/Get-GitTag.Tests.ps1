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
    # Arrange
    git -C $repo tag 'v1.2.0' 2>&1 | Out-Null
    git -C $repo tag 'v1.10.0' 2>&1 | Out-Null
    git -C $repo tag 'v1.9.0' 2>&1 | Out-Null
    git -C $repo tag 'other' 2>&1 | Out-Null

    # Act - every tag, no filter
    $all = @(Get-GitTag -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 4 -Actual $all.Count -Message 'Every tag is returned with no -Pattern'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -Pattern filters
    $filtered = @(Get-GitTag -Pattern 'v*' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 3 -Actual $filtered.Count -Message '-Pattern filters out non-matching tags'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -SortByVersion sorts numerically, not lexically
    $sorted = @(Get-GitTag -Pattern 'v*' -SortByVersion -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 'v1.10.0' -Actual $sorted[0] -Message 'The highest version sorts first, not lexically'
    Assert-Equal -Expected 'v1.9.0' -Actual $sorted[1] -Message 'The second-highest version comes next'
    Assert-Equal -Expected 'v1.2.0' -Actual $sorted[2] -Message 'The lowest version comes last'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -SortByVersion skips a tag that is not a valid version
    $withInvalid = @(Get-GitTag -SortByVersion -RepoPath $repo)

    # Assert
    Assert-That -Condition ($withInvalid -notcontains 'other') -Message 'A non-version tag is skipped, not errored on'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - without -SortByVersion, git's own alphabetical order
    Assert-Equal -Expected 'other, v1.10.0, v1.2.0, v1.9.0' -Actual ($all -join ', ') `
        -Message 'The default order is alphabetical, not the order the tags were made in'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - no tag is a version at all
    Assert-Equal -Expected 0 -Actual @(Get-GitTag -Pattern 'other' -SortByVersion -RepoPath $repo).Count `
        -Message '-SortByVersion over tags that are none of them versions returns nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tag with two leading v's, and one with a capital V
    git -C $repo tag vv3.0.0 2>&1 | Out-Null
    git -C $repo tag V4.0.0 2>&1 | Out-Null

    # Act
    $doubled = @(Get-GitTag -SortByVersion -RepoPath $repo)

    # Assert
    Assert-Equal -Expected @('v1.10.0', 'v1.9.0', 'v1.2.0') -Actual $doubled `
        -Message 'Only one leading lowercase v is dropped, so vv3.0.0 and V4.0.0 are not versions'
    git -C $repo tag -d vv3.0.0 V4.0.0 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - an option-like pattern
    Assert-Throws -ScriptBlock {
        Get-GitTag -Pattern '--delete' -RepoPath $repo
    } -MessageLike "*'--delete' is blank or starts with '-'*" -Message 'A pattern starting with a dash is refused'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a user config that lays tags out in columns and sorts them backward
    git -C $repo config column.ui always 2>&1 | Out-Null
    git -C $repo config tag.sort -refname 2>&1 | Out-Null

    # Act
    $configured = @(Get-GitTag -RepoPath $repo)

    # Assert
    Assert-Equal -Expected @('other', 'v1.10.0', 'v1.2.0', 'v1.9.0') -Actual $configured `
        -Message 'One tag per item, in alphabetical order, whatever column.ui and tag.sort say'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tag inside a folder-like name, and a short one that starts alike
    git -C $repo tag 'release/1.0' 2>&1 | Out-Null
    git -C $repo tag 'rel' 2>&1 | Out-Null

    # Act
    $wildcard = @(Get-GitTag -Pattern 're*' -RepoPath $repo)
    $exact = @(Get-GitTag -Pattern 'rel' -RepoPath $repo)
    $folder = @(Get-GitTag -Pattern 'release' -RepoPath $repo)

    # Assert
    Assert-Equal -Expected @(git -C $repo tag --list --no-column --sort=refname 're*') -Actual $wildcard `
        -Message 'A pattern matches exactly what git tag --list matches'
    Assert-Equal -Expected @('rel', 'release/1.0') -Actual $wildcard -Message 'so a * reaches past a /'
    Assert-Equal -Expected @('rel') -Actual $exact `
        -Message 'a pattern with no wildcard matches only the tag of that name'
    Assert-Equal -Expected @() -Actual $folder -Message 'and not the tags under it'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
