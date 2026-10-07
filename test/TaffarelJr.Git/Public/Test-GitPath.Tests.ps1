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
    # Arrange / Act / Assert - a tracked path, checked right now
    Assert-Equal -Expected $true -Actual (Test-GitPath -Path 'a.txt' -RepoPath $repo) -Message 'A tracked path reports true'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a path that was never tracked
    Assert-Equal -Expected $false -Actual (Test-GitPath -Path 'nope.txt' -RepoPath $repo) -Message 'An untracked path reports false'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - delete the file in a later commit
    $firstCommit = (git -C $repo rev-parse HEAD).Trim()
    Remove-Item -LiteralPath (Join-Path $repo 'a.txt')
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'remove a' 2>&1 | Out-Null

    # Act / Assert - not tracked now, but present at the earlier ref
    Assert-Equal -Expected $false -Actual (Test-GitPath -Path 'a.txt' -RepoPath $repo) -Message 'A deleted path is no longer tracked now'
    Assert-Equal -Expected $true -Actual (Test-GitPath -Path 'a.txt' -Ref $firstCommit -RepoPath $repo) `
        -Message '-Ref finds it at the commit where it still existed'
    Assert-Equal -Expected $false -Actual (Test-GitPath -Path 'a.txt' -Ref 'HEAD' -RepoPath $repo) `
        -Message '-Ref at the current commit correctly reports it missing'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
