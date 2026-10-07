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
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'second' 2>&1 | Out-Null

    # Act / Assert - defaults to HEAD
    $head = Get-GitCommit -RepoPath $repo
    Assert-Equal -Expected 'second' -Actual $head.Subject -Message 'Defaults to describing HEAD'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - an explicit ref
    $explicit = Get-GitCommit -Ref $first -RepoPath $repo
    Assert-Equal -Expected 'initial' -Actual $explicit.Subject -Message 'Describes the given ref instead'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a ref that does not exist
    Assert-Equal -Expected $null -Actual (Get-GitCommit -Ref 'not-a-real-ref' -RepoPath $repo) `
        -Message 'A nonexistent ref returns $null instead of throwing'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
