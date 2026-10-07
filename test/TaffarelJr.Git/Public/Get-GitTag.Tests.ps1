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
    git -C $repo tag 'v1.2.0' 2>&1 | Out-Null
    git -C $repo tag 'v1.10.0' 2>&1 | Out-Null
    git -C $repo tag 'v1.9.0' 2>&1 | Out-Null
    git -C $repo tag 'other' 2>&1 | Out-Null

    # Act / Assert - every tag, no filter
    $all = Get-GitTag -RepoPath $repo
    Assert-Equal -Expected 4 -Actual $all.Count -Message 'Every tag is returned with no -Pattern'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - -Pattern filters
    $filtered = Get-GitTag -Pattern 'v*' -RepoPath $repo
    Assert-Equal -Expected 3 -Actual $filtered.Count -Message '-Pattern filters out non-matching tags'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - -SortByVersion sorts numerically, not lexically
    $sorted = Get-GitTag -Pattern 'v*' -SortByVersion -RepoPath $repo
    Assert-Equal -Expected 'v1.10.0' -Actual $sorted[0] -Message 'The highest version sorts first, not lexically'
    Assert-Equal -Expected 'v1.9.0' -Actual $sorted[1] -Message 'The second-highest version comes next'
    Assert-Equal -Expected 'v1.2.0' -Actual $sorted[2] -Message 'The lowest version comes last'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - -SortByVersion skips a tag that is not a valid version
    $withInvalid = Get-GitTag -SortByVersion -RepoPath $repo
    Assert-That -Condition ($withInvalid -notcontains 'other') -Message 'A non-version tag is skipped, not errored on'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
