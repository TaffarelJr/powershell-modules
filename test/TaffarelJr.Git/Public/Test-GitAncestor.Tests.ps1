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
    $base = (git -C $repo rev-parse HEAD).Trim()
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'second' 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected $true -Actual (Test-GitAncestor -Ancestor $base -Descendant 'HEAD' -RepoPath $repo) `
        -Message 'An earlier commit is an ancestor of a later one'
    Assert-Equal -Expected $false -Actual (Test-GitAncestor -Ancestor 'HEAD' -Descendant $base -RepoPath $repo) `
        -Message 'The reverse direction is false'
    Assert-Equal -Expected $true -Actual (Test-GitAncestor -Ancestor 'HEAD' -Descendant 'HEAD' -RepoPath $repo) `
        -Message 'A commit is its own ancestor'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
