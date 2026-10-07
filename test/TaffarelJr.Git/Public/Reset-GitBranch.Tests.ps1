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
    Assert-Equal -Expected 'initial' -Actual (Get-GitCommit -RepoPath $repo).Subject `
        -Message 'Soft moves HEAD back one commit'
    Assert-Equal -Expected $true -Actual (Test-GitChange -Staged -RepoPath $repo) `
        -Message "Soft leaves the undone commit's change staged"

    #───────────────────────────────────────────────────────────────────────────
    # Act - -Mode Hard discards the working tree change entirely
    Reset-GitBranch -Mode Hard -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitStatus -RepoPath $repo).Count `
        -Message 'Hard leaves a fully clean working tree'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a branch named like a tracked folder, one commit back
    New-Item -ItemType Directory -Path (Join-Path $repo 'src') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'src/x.txt') -Value 'x' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add src' 2>&1 | Out-Null
    git -C $repo branch src HEAD~1 2>&1 | Out-Null
    git -C $repo commit --quiet --allow-empty -m 'later' 2>&1 | Out-Null

    # Act
    Reset-GitBranch -Ref 'src' -Mode Hard -RepoPath $repo

    # Assert
    Assert-Equal -Expected (Resolve-GitRef -Ref 'refs/heads/src' -RepoPath $repo) `
        -Actual (Resolve-GitRef -Ref 'HEAD' -RepoPath $repo) `
        -Message 'A ref named like a folder is read as the ref'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository with no commits yet, and a staged file
$empty = New-GitTestRepo -NoCommit
try {
    Set-Content -LiteralPath (Join-Path $empty 'x.txt') -Value 'x' -NoNewline
    git -C $empty add -A 2>&1 | Out-Null

    # Act
    Reset-GitBranch -RepoPath $empty

    # Assert
    $status = @(Get-GitStatus -RepoPath $empty)
    Assert-Equal -Expected '??' -Actual $status[0].Status `
        -Message 'The default un-stages everything even before the first commit'
}
finally {
    Remove-GitTestRepo -Path $empty
}

exit (Complete-TestRun)
