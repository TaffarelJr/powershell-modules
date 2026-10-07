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
    # Arrange - a fully-merged branch
    git -C $repo branch merged 2>&1 | Out-Null

    # Act
    Remove-GitBranch -Name 'merged' -RepoPath $repo

    # Assert
    $branches = Get-GitBranch -List -RepoPath $repo
    Assert-That -Condition ($branches -notcontains 'merged') -Message 'A merged branch is deleted without -Force'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an unmerged branch
    git -C $repo checkout -q -b unmerged 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'unmerged work' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'unmerged commit' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null

    # Act / Assert - refused without -Force
    Assert-Throws -ScriptBlock { Remove-GitBranch -Name 'unmerged' -RepoPath $repo } `
        -Message 'An unmerged branch is refused without -Force'

    # Act - -Force deletes it anyway
    Remove-GitBranch -Name 'unmerged' -Force -RepoPath $repo

    # Assert
    $afterForce = Get-GitBranch -List -RepoPath $repo
    Assert-That -Condition ($afterForce -notcontains 'unmerged') -Message '-Force deletes an unmerged branch'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two more branches, to delete via the pipeline
    git -C $repo branch pipe1 2>&1 | Out-Null
    git -C $repo branch pipe2 2>&1 | Out-Null

    # Act
    @('pipe1', 'pipe2') | Remove-GitBranch -RepoPath $repo

    # Assert
    $afterPipe = Get-GitBranch -List -RepoPath $repo
    Assert-That -Condition ($afterPipe -notcontains 'pipe1') -Message 'The first piped branch is deleted'
    Assert-That -Condition ($afterPipe -notcontains 'pipe2') -Message 'The second piped branch is deleted'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
