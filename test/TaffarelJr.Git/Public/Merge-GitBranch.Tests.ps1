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
    # Arrange - a feature branch with no conflicting changes
    git -C $repo checkout -q -b feature 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add b' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null

    # Act
    $clean = Merge-GitBranch -Ref 'feature' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual $clean.Conflict -Message 'A clean merge reports no conflict'
    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath (Join-Path $repo 'b.txt')) -Message "feature's file is now present"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a fast-forward-able branch
    git -C $repo checkout -q -b ff-branch 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'c' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add c' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    $beforeHead = (git -C $repo rev-parse HEAD).Trim()

    # Act / Assert - -NoFastForward always creates a merge commit
    Merge-GitBranch -Ref 'ff-branch' -NoFastForward -RepoPath $repo | Out-Null
    $log = Get-GitLog -Count 1 -RepoPath $repo
    Assert-That -Condition ($log[0].Subject -like 'Merge*') -Message '-NoFastForward creates a real merge commit instead of fast-forwarding'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two branches that conflict on the same file
    git -C $repo checkout -q -b conflict-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-a' -NoNewline
    git -C $repo commit --quiet -am 'change on a' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'from-main' -NoNewline
    git -C $repo commit --quiet -am 'change on main' 2>&1 | Out-Null

    # Act
    $conflicted = Merge-GitBranch -Ref 'conflict-a' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $conflicted.Conflict -Message 'A conflicting merge reports a conflict'
    Assert-Equal -Expected 'a.txt' -Actual $conflicted.Paths[0] -Message 'The conflicted path is reported'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
