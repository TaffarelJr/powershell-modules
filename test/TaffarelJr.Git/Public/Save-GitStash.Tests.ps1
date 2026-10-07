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
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline

    # Act
    $saved = Save-GitStash -Message 'wip work' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $saved -Message 'Saving changes reports that a stash was created'
    Assert-Equal -Expected 0 -Actual @(Get-GitStatus -RepoPath $repo).Count `
        -Message 'Stashing leaves a clean working tree'
    $stashes = @(Get-GitStash -RepoPath $repo)
    Assert-Equal -Expected 1 -Actual $stashes.Count -Message 'The stash is recorded'
    Assert-That -Condition ($stashes[0].Message -like '*wip work*') -Message 'The stash carries the given message'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act - -IncludeUntracked also stashes a new file
    Set-Content -LiteralPath (Join-Path $repo 'untracked.txt') -Value 'new' -NoNewline
    Save-GitStash -Message 'with untracked' -IncludeUntracked -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'untracked.txt')) `
        -Message '-IncludeUntracked stashes a new file too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a clean tree, with older stashes already waiting
    $before = @(Get-GitStash -RepoPath $repo).Count

    # Act
    $nothing = Save-GitStash -Message 'nothing to save' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual $nothing `
        -Message 'With nothing to stash, it reports that no stash was created'
    Assert-Equal -Expected $before -Actual @(Get-GitStash -RepoPath $repo).Count `
        -Message 'and the stash list is untouched, so a later Restore-GitStash is not aimed at an older one'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
