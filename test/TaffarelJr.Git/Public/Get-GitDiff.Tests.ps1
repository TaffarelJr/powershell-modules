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
    # Arrange - an unstaged change
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline

    # Act / Assert - the default diffs the working tree
    $diff = Get-GitDiff -RepoPath $repo
    Assert-That -Condition (($diff -join "`n") -match 'a\.txt') -Message 'The default diffs the working tree against HEAD'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - stage it
    git -C $repo add -A 2>&1 | Out-Null

    # Act / Assert - -Staged diffs the index instead
    $staged = Get-GitDiff -Staged -NameOnly -RepoPath $repo
    Assert-Equal -Expected 'a.txt' -Actual ($staged -join '') -Message '-Staged -NameOnly lists just the staged path'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a second commit
    git -C $repo commit --quiet -m 'change a' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'new' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add b' 2>&1 | Out-Null

    # Act / Assert - -NameStatus between two refs
    $nameStatus = Get-GitDiff -FromRef 'HEAD~2' -ToRef 'HEAD' -NameStatus -RepoPath $repo
    Assert-Equal -Expected 2 -Actual $nameStatus.Count -Message 'Both changed paths are listed'
    Assert-That -Condition (($nameStatus -join "`n") -match '^[AM]\t') -Message 'Status letters are included'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - -Path scopes the diff to one file
    $scoped = Get-GitDiff -FromRef 'HEAD~2' -ToRef 'HEAD' -NameOnly -Path 'b.txt' -RepoPath $repo
    Assert-Equal -Expected 'b.txt' -Actual ($scoped -join '') -Message '-Path scopes the result to that file alone'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
