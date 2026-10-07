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
    $first = (git -C $repo rev-parse HEAD).Trim()
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'more' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'second' 2>&1 | Out-Null

    # Act / Assert - the root is the first commit, not the current tip
    $root = Get-GitRootCommit -RepoPath $repo
    Assert-Equal -Expected 1 -Actual $root.Count -Message 'A linear history has exactly one root'
    Assert-Equal -Expected $first -Actual $root[0] -Message 'The root is the very first commit'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
