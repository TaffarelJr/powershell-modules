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
    # Arrange - two branches diverging from the same commit
    $base = (git -C $repo rev-parse HEAD).Trim()
    git -C $repo checkout -q -b branch-a 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'a-change' -NoNewline
    git -C $repo commit --quiet -am 'a change' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'main-change' -NoNewline
    git -C $repo commit --quiet -am 'main change' 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected $base -Actual (Get-GitMergeBase -Ref1 'main' -Ref2 'branch-a' -RepoPath $repo) `
        -Message 'Finds the commit where both branches diverged'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an orphan branch sharing no history with main, in the same repo
    git -C $repo checkout -q --orphan 'unrelated' 2>&1 | Out-Null
    git -C $repo rm -qrf . 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'z.txt') -Value 'z' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'orphan root' 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected $null -Actual (Get-GitMergeBase -Ref1 'main' -Ref2 'unrelated' -RepoPath $repo) `
        -Message 'Unrelated histories have no merge base'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
