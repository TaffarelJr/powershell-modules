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
    $head = (git -C $repo rev-parse HEAD).Trim()

    # Act / Assert - HEAD resolves to the same SHA git itself reports
    Assert-Equal -Expected $head -Actual (Resolve-GitRef -Ref 'HEAD' -RepoPath $repo) -Message 'HEAD resolves to its commit SHA'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a branch name resolves the same way
    Assert-Equal -Expected $head -Actual (Resolve-GitRef -Ref 'main' -RepoPath $repo) -Message 'A branch name resolves to its tip commit'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a ref that does not exist
    Assert-Equal -Expected $null -Actual (Resolve-GitRef -Ref 'nope-not-real' -RepoPath $repo) `
        -Message 'A nonexistent ref returns $null instead of throwing'

    #───────────────────────────────────────────────────────────────────────────
    # Act - piping several refs resolves each one
    $results = @('HEAD', 'main') | Resolve-GitRef -RepoPath $repo

    # Assert
    Assert-Equal -Expected 2 -Actual $results.Count -Message 'Each piped ref produces its own result'
    Assert-Equal -Expected $head -Actual $results[0] -Message 'The first piped ref resolves correctly'
    Assert-Equal -Expected $head -Actual $results[1] -Message 'The second piped ref resolves correctly'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
