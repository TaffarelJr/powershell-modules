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
    # Arrange / Act / Assert - nothing staged yet
    Assert-Equal -Expected $false -Actual (Test-GitChange -Staged -RepoPath $repo) -Message 'Nothing staged reports false'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null

    # Act / Assert - the default parameter set is staged
    Assert-Equal -Expected $true -Actual (Test-GitChange -RepoPath $repo) -Message 'The default checks staged changes'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    git -C $repo commit --quiet -m 'change a' 2>&1 | Out-Null
    $before = (git -C $repo rev-parse HEAD~1).Trim()
    $after = (git -C $repo rev-parse HEAD).Trim()

    # Act / Assert - a path that changed between two refs
    Assert-Equal -Expected $true -Actual (Test-GitChange -FromRef $before -ToRef $after -Path 'a.txt' -RepoPath $repo) `
        -Message 'A path that changed between two refs reports true'

    # Act / Assert - a path that did not change between the same two refs
    Set-Content -LiteralPath (Join-Path $repo 'untouched.txt') -Value 'x' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add untouched' 2>&1 | Out-Null
    Assert-Equal -Expected $false -Actual (Test-GitChange -FromRef $after -ToRef 'HEAD' -Path 'a.txt' -RepoPath $repo) `
        -Message 'An unrelated path between two refs reports false'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
