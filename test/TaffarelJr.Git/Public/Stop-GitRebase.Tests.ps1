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
    # Arrange - a rebase paused on a conflict
    git -C $repo checkout -q -b feature 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'feature' -NoNewline
    git -C $repo commit --quiet -am 'feature change' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'main' -NoNewline
    git -C $repo commit --quiet -am 'main change' 2>&1 | Out-Null
    git -C $repo checkout -q feature 2>&1 | Out-Null
    $beforeRebase = (git -C $repo rev-parse HEAD).Trim()
    git -C $repo rebase main 2>&1 | Out-Null

    # Act
    Stop-GitRebase -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-GitRebaseInProgress -RepoPath $repo) -Message 'The rebase is no longer in progress'
    Assert-Equal -Expected $beforeRebase -Actual (Resolve-GitRef -Ref 'HEAD' -RepoPath $repo) `
        -Message 'The branch is restored to where it was before the rebase started'
    Assert-Equal -Expected 'feature' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) `
        -Message "feature's own content is back, not main's"
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
