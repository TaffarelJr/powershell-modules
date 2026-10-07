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
    # Arrange - a staged change
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null

    # Act - the default (Mixed) un-stages without touching the working tree
    Reset-GitBranch -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-GitChange -Staged -RepoPath $repo) -Message 'Mixed un-stages the change'
    Assert-Equal -Expected 'changed' -Actual (Get-Content -LiteralPath (Join-Path $repo 'a.txt') -Raw) `
        -Message 'Mixed leaves the working tree content alone'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'change a' 2>&1 | Out-Null

    # Act - -Mode Soft moves HEAD but keeps the change staged
    Reset-GitBranch -Ref 'HEAD~1' -Mode Soft -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'initial' -Actual (Get-GitCommit -RepoPath $repo).Subject -Message 'Soft moves HEAD back one commit'
    Assert-Equal -Expected $true -Actual (Test-GitChange -Staged -RepoPath $repo) -Message "Soft leaves the undone commit's change staged"

    #───────────────────────────────────────────────────────────────────────────
    # Act - -Mode Hard discards the working tree change entirely
    Reset-GitBranch -Mode Hard -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual (Get-GitStatus -RepoPath $repo).Count -Message 'Hard leaves a fully clean working tree'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
