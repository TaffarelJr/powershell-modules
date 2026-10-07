#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$upstream = New-GitTestRepo
$repo = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a clone, then a new commit upstream
    git clone --quiet $upstream $repo 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $upstream 'b.txt') -Value 'b' -NoNewline
    git -C $upstream add -A 2>&1 | Out-Null
    git -C $upstream commit --quiet -m 'second' 2>&1 | Out-Null

    # Act
    Update-GitBranch -RepoPath $repo

    # Assert
    Assert-Equal -Expected (Resolve-GitRef -Ref 'main' -RepoPath $upstream) -Actual (Resolve-GitRef -Ref 'HEAD' -RepoPath $repo) `
        -Message 'Pulling brings the local branch up to date with upstream'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - diverging histories on both sides
    Set-Content -LiteralPath (Join-Path $upstream 'c.txt') -Value 'c' -NoNewline
    git -C $upstream add -A 2>&1 | Out-Null
    git -C $upstream commit --quiet -m 'upstream change' 2>&1 | Out-Null

    Set-Content -LiteralPath (Join-Path $repo 'd.txt') -Value 'd' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'local change' 2>&1 | Out-Null

    # Act - -Rebase replays the local commit on top instead of merging
    Update-GitBranch -Rebase -RepoPath $repo

    # Assert
    $log = Get-GitLog -Count 3 -RepoPath $repo
    Assert-Equal -Expected 'local change' -Actual $log[0].Subject -Message '-Rebase replays the local commit on top'
    Assert-Equal -Expected 'upstream change' -Actual $log[1].Subject -Message 'The upstream commit now comes before it'
    Assert-That -Condition ($log.Subject -notcontains 'Merge') -Message 'No merge commit is created'
}
finally {
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
