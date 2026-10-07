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
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline
    Save-GitStash -Message 'wip' -RepoPath $repo

    # Act
    Restore-GitStash -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'changed' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) -Message 'The change comes back'
    Assert-Equal -Expected 0 -Actual (Get-GitStash -RepoPath $repo).Count -Message 'Restoring removes the stash from the list'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two stashes, restoring a specific index
    git -C $repo checkout -q -- a.txt 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'first' -NoNewline
    Save-GitStash -Message 'first stash' -RepoPath $repo
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'second' -NoNewline
    Save-GitStash -Message 'second stash' -RepoPath $repo

    # Act - index 1 is the OLDER of the two (0 is most recent)
    Restore-GitStash -Index 1 -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'first' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) -Message 'The chosen stash index is restored'
    Assert-Equal -Expected 1 -Actual (Get-GitStash -RepoPath $repo).Count -Message 'Only the restored stash is removed'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
