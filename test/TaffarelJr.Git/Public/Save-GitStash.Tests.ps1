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

    # Act
    Save-GitStash -Message 'wip work' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual (Get-GitStatus -RepoPath $repo).Count -Message 'Stashing leaves a clean working tree'
    $stashes = Get-GitStash -RepoPath $repo
    Assert-Equal -Expected 1 -Actual $stashes.Count -Message 'The stash is recorded'
    Assert-That -Condition ($stashes[0].Message -like '*wip work*') -Message 'The stash carries the given message'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - -IncludeUntracked also stashes a new file
    Set-Content -LiteralPath (Join-Path $repo 'untracked.txt') -Value 'new' -NoNewline
    Save-GitStash -Message 'with untracked' -IncludeUntracked -RepoPath $repo
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'untracked.txt')) `
        -Message '-IncludeUntracked stashes a new file too'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
