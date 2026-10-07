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
    $first = (git -C $repo rev-parse HEAD).Trim()
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'second' 2>&1 | Out-Null

    # Act - defaults to HEAD
    $head = Get-GitCommit -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'second' -Actual $head.Subject -Message 'Defaults to describing HEAD'

    #───────────────────────────────────────────────────────────────────────────
    # Act - an explicit ref
    $explicit = Get-GitCommit -Ref $first -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'initial' -Actual $explicit.Subject -Message 'Describes the given ref instead'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a ref that does not exist
    Assert-Equal -Expected $null -Actual (Get-GitCommit -Ref 'not-a-real-ref' -RepoPath $repo) `
        -Message 'A nonexistent ref returns $null instead of throwing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a branch named like a tracked folder
    New-Item -ItemType Directory -Path (Join-Path $repo 'src') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'src/x.txt') -Value 'x' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add src' 2>&1 | Out-Null
    git -C $repo branch src 2>&1 | Out-Null

    # Act
    $byBranch = Get-GitCommit -Ref 'src' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'add src' -Actual $byBranch.Subject -Message 'A ref named like a folder is read as the ref'
}
finally {
    Remove-GitTestRepo -Path $repo
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$plain = New-GitTestFolder
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Get-GitCommit -RepoPath $plain } `
        -MessageLike '*Resolving HEAD failed*not a git repository*' `
        -Message 'A folder that is no repository throws rather than reading as no such commit'
}
finally {
    Remove-GitTestRepo -Path $plain
}

exit (Complete-TestRun)
