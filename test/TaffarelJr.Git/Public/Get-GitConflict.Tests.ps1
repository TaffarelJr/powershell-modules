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
    # Arrange / Act / Assert - no conflicts outside a merge
    Assert-Equal -Expected 0 -Actual (Get-GitConflict -RepoPath $repo).Count -Message 'A clean repo has no conflicts'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two branches that conflict on the same file
    git -C $repo checkout -q -b branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-a' -NoNewline
    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-main' -NoNewline
    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null
    git -C $repo merge --no-edit branch-a 2>&1 | Out-Null

    # Act / Assert
    $conflicts = Get-GitConflict -RepoPath $repo
    Assert-Equal -Expected 1 -Actual $conflicts.Count -Message 'The conflicted path is reported'
    Assert-Equal -Expected 'a.txt' -Actual $conflicts[0] -Message 'The correct path is reported'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
