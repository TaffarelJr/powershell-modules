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
    # Act
    Move-GitFile -Path 'a.txt' -Destination 'renamed.txt' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'a.txt')) -Message 'The old path no longer exists on disk'
    Assert-Equal -Expected $true -Actual (Test-Path -LiteralPath (Join-Path $repo 'renamed.txt')) -Message 'The new path exists on disk'
    Assert-Equal -Expected $true -Actual (Test-GitChange -Staged -RepoPath $repo) -Message 'The rename is already staged'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a destination that already exists
    git -C $repo commit --quiet -m 'rename' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'taken.txt') -Value 'existing' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add taken' 2>&1 | Out-Null

    # Act / Assert - refused without -Force
    Assert-Throws -ScriptBlock { Move-GitFile -Path 'renamed.txt' -Destination 'taken.txt' -RepoPath $repo } `
        -Message 'Moving onto an existing path is refused without -Force'

    # Act - -Force overwrites it
    Move-GitFile -Path 'renamed.txt' -Destination 'taken.txt' -Force -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'renamed.txt')) -Message '-Force completes the move'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
