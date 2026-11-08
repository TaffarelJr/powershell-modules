#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

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

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a ref that does not exist is an error, not a "no"
    Assert-Throws -ScriptBlock {
        Test-GitAncestor -Ancestor 'no-such-ref' -Descendant 'HEAD' -RepoPath $repo
    } -MessageLike '*Checking whether no-such-ref is an ancestor of HEAD failed*' `
        -Message 'A bad ref throws instead of answering $false'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
