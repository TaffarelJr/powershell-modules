#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$upstream = New-GitTestRepo
$repo = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a clone with no divergence yet
    git clone --quiet $upstream $repo 2>&1 | Out-Null

    # Act / Assert
    $clean = Compare-GitBranch -RepoPath $repo
    Assert-Equal -Expected 0 -Actual $clean.Ahead -Message 'A fresh clone is not ahead'
    Assert-Equal -Expected 0 -Actual $clean.Behind -Message 'A fresh clone is not behind'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - diverge both sides
    Set-Content -LiteralPath (Join-Path $upstream 'b.txt') -Value 'b' -NoNewline
    git -C $upstream add -A 2>&1 | Out-Null
    git -C $upstream commit --quiet -m 'upstream change' 2>&1 | Out-Null
    git -C $repo fetch --quiet origin 2>&1 | Out-Null

    Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'c' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'local change' 2>&1 | Out-Null

    # Act / Assert - explicit -Upstream, since the remote-tracking ref moved via fetch, not pull
    $diverged = Compare-GitBranch -Upstream 'origin/main' -RepoPath $repo
    Assert-Equal -Expected 1 -Actual $diverged.Ahead -Message 'One local commit not on the upstream'
    Assert-Equal -Expected 1 -Actual $diverged.Behind -Message 'One upstream commit not local yet'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - no upstream configured for a plain local branch
    git -C $repo branch 'no-upstream' 2>&1 | Out-Null
    Assert-Equal -Expected $null -Actual (Compare-GitBranch -Branch 'no-upstream' -RepoPath $repo) `
        -Message 'A branch with no configured upstream returns $null'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
