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
    # Arrange / Act / Assert - no stashes yet
    Assert-Equal -Expected 0 -Actual (Get-GitStash -RepoPath $repo).Count -Message 'A repo with no stashes returns nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two stashes
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'first' -NoNewline
    git -C $repo stash push --quiet -m 'first stash' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'second' -NoNewline
    git -C $repo stash push --quiet -m 'second stash' 2>&1 | Out-Null

    # Act
    $stashes = Get-GitStash -RepoPath $repo

    # Assert
    Assert-Equal -Expected 2 -Actual $stashes.Count -Message 'Both stashes are listed'
    Assert-Equal -Expected 0 -Actual $stashes[0].Index -Message 'The most recent stash is index 0'
    Assert-That -Condition ($stashes[0].Message -like '*second stash*') -Message 'The most recent stash is listed first'
    Assert-Equal -Expected 1 -Actual $stashes[1].Index -Message 'The older stash is index 1'
    Assert-That -Condition ($stashes[1].Message -like '*first stash*') -Message 'The older stash comes second'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
