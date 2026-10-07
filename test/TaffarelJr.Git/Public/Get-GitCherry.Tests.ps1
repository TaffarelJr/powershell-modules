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
    # Arrange - a commit on a feature branch, not yet on main
    git -C $repo checkout -q -b feature 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'feature commit' 2>&1 | Out-Null
    $featureCommit = (git -C $repo rev-parse HEAD).Trim()

    # Act / Assert - main is missing the feature commit's patch
    $missing = Get-GitCherry -Base 'main' -Upstream 'feature' -RepoPath $repo
    Assert-Equal -Expected 1 -Actual $missing.Count -Message "One commit is reported"
    Assert-Equal -Expected '+' -Actual $missing[0].Status -Message 'A missing patch is marked +'
    Assert-Equal -Expected $featureCommit -Actual $missing[0].Hash -Message 'The hash matches the feature commit'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - apply the same change to main via a fresh commit (same patch, different SHA)
    git -C $repo checkout -q main 2>&1 | Out-Null
    git -C $repo cherry-pick --quiet $featureCommit 2>&1 | Out-Null

    # Act / Assert - the equivalent patch is now recognized, despite a different SHA
    $applied = Get-GitCherry -Base 'main' -Upstream 'feature' -RepoPath $repo
    Assert-Equal -Expected 1 -Actual $applied.Count -Message 'One commit is still reported'
    Assert-Equal -Expected '-' -Actual $applied[0].Status -Message 'An equivalent patch already present is marked -'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
