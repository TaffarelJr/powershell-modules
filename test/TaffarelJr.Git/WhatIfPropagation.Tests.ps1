#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# A caller's -WhatIf sets $WhatIfPreference in the caller's own scope, which a
# module function never sees unless it copies it. Each command that changes
# something is called here from a caller's function given -WhatIf, against a
# repository set up so the real call would change it.

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot 'GitTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

$skipReason = Get-GitTestSkipReason
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$temp = [System.IO.Path]::GetTempPath()
$upstream = Join-Path $temp "git-upstream-$([Guid]::NewGuid()).git"
$clone = Join-Path $temp "git-test-$([Guid]::NewGuid())"
$ahead = Join-Path $temp "git-test-$([Guid]::NewGuid())"
$copy = Join-Path $temp "git-copy-$([Guid]::NewGuid())"
$dirty = New-GitTestPathRepo -Path 'b.txt'
$merging = New-GitTestRepo
$rebasing = New-GitTestRepo
try {
    # Arrange - a clone that has diverged from its upstream, with a side branch
    # of its own, a merged branch, and a tag
    git init --quiet --bare --initial-branch=main $upstream 2>&1 | Out-Null
    git -C $dirty push --quiet $upstream main 2>&1 | Out-Null
    foreach ($path in $clone, $ahead) {
        git clone --quiet $upstream $path 2>&1 | Out-Null
        git -C $path config user.name 'Test' 2>&1 | Out-Null
        git -C $path config user.email 'test@example.com' 2>&1 | Out-Null
    }

    git -C $ahead commit --quiet --allow-empty -m 'upstream' 2>&1 | Out-Null
    git -C $ahead push --quiet origin main 2>&1 | Out-Null
    git -C $clone branch done 2>&1 | Out-Null
    git -C $clone checkout -q -b side 2>&1 | Out-Null
    git -C $clone commit --quiet --allow-empty -m 'side' 2>&1 | Out-Null
    git -C $clone checkout -q main 2>&1 | Out-Null
    git -C $clone commit --quiet --allow-empty -m 'local' 2>&1 | Out-Null
    git -C $clone tag v1 2>&1 | Out-Null

    # a repository with a stash, a staged change and an untracked file
    Set-Content -LiteralPath (Join-Path $dirty 'a.txt') -Value 'stashed' -NoNewline
    git -C $dirty stash --quiet 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $dirty 'b.txt') -Value 'staged' -NoNewline
    git -C $dirty add b.txt 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $dirty 'new.txt') -Value 'untracked' -NoNewline

    # a merge stopped on a conflict in a.txt
    git -C $merging checkout -q -b side 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $merging 'a.txt') -Value 'from side' -NoNewline
    git -C $merging commit --quiet -am 'side' 2>&1 | Out-Null
    git -C $merging checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $merging 'a.txt') -Value 'from main' -NoNewline
    git -C $merging commit --quiet -am 'main' 2>&1 | Out-Null
    git -C $merging merge --no-edit side 2>&1 | Out-Null

    # a rebase stopped on a conflict in a.txt, the second of two commits
    git -C $rebasing checkout -q -b topic 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $rebasing 'b.txt') -Value 'from topic' -NoNewline
    git -C $rebasing add b.txt 2>&1 | Out-Null
    git -C $rebasing commit --quiet -m 'topic b' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $rebasing 'a.txt') -Value 'from topic' -NoNewline
    git -C $rebasing commit --quiet -am 'topic a' 2>&1 | Out-Null
    git -C $rebasing checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $rebasing 'a.txt') -Value 'from main' -NoNewline
    git -C $rebasing commit --quiet -am 'main' 2>&1 | Out-Null
    git -C $rebasing checkout -q topic 2>&1 | Out-Null
    git -C $rebasing rebase main 2>&1 | Out-Null

    $rows = @(
        @{ Name = 'Add-GitChange'; Repo = $dirty; Call = { Add-GitChange -Path 'new.txt' -RepoPath $dirty } }
        @{ Name = 'Copy-GitRepository'; Repo = $clone; Call = { Copy-GitRepository -Url $upstream -Destination $copy } }
        @{ Name = 'Merge-GitBranch'; Repo = $clone; Call = { Merge-GitBranch -Ref 'side' -RepoPath $clone } }
        @{
            Name = 'Move-GitFile'
            Repo = $dirty
            Call = { Move-GitFile -Path 'a.txt' -Destination 'c.txt' -RepoPath $dirty }
        }
        @{ Name = 'New-GitBranch'; Repo = $clone; Call = { New-GitBranch -Name 'made' -RepoPath $clone } }
        @{ Name = 'New-GitCommit'; Repo = $dirty; Call = { New-GitCommit -Message 'made' -RepoPath $dirty } }
        @{ Name = 'New-GitTag'; Repo = $clone; Call = { New-GitTag -Name 'v2' -RepoPath $clone } }
        @{ Name = 'Push-GitCommit'; Repo = $clone; Call = { Push-GitCommit -Branch 'side' -RepoPath $clone } }
        @{ Name = 'Remove-GitBranch'; Repo = $clone; Call = { Remove-GitBranch -Name 'done' -RepoPath $clone } }
        @{ Name = 'Remove-GitFile'; Repo = $dirty; Call = { Remove-GitFile -Path 'a.txt' -RepoPath $dirty } }
        @{ Name = 'Remove-GitRemote'; Repo = $clone; Call = { Remove-GitRemote -Name 'origin' -RepoPath $clone } }
        @{ Name = 'Remove-GitTag'; Repo = $clone; Call = { Remove-GitTag -Name 'v1' -RepoPath $clone } }
        @{
            Name = 'Reset-GitBranch'
            Repo = $clone
            Call = { Reset-GitBranch -Ref 'HEAD~1' -Mode Hard -RepoPath $clone }
        }
        @{
            Name = 'Resolve-GitConflict'
            Repo = $merging
            Call = { Resolve-GitConflict -Path 'a.txt' -Side Theirs -RepoPath $merging }
        }
        @{ Name = 'Restore-GitStash'; Repo = $dirty; Call = { Restore-GitStash -RepoPath $dirty } }
        @{ Name = 'Resume-GitRebase'; Repo = $rebasing; Call = { Resume-GitRebase -RepoPath $rebasing } }
        @{ Name = 'Save-GitStash'; Repo = $dirty; Call = { Save-GitStash -RepoPath $dirty } }
        @{
            Name = 'Set-GitConfig'
            Repo = $clone
            Call = { Set-GitConfig -Name 'test.key' -Value 'set' -RepoPath $clone }
        }
        @{
            Name = 'Set-GitRemote'
            Repo = $clone
            Call = { Set-GitRemote -Name 'other' -Url 'https://example.com/o/r.git' -RepoPath $clone }
        }
        @{ Name = 'Start-GitRebase'; Repo = $clone; Call = { Start-GitRebase -Ref 'side' -RepoPath $clone } }
        @{ Name = 'Stop-GitRebase'; Repo = $rebasing; Call = { Stop-GitRebase -RepoPath $rebasing } }
        @{ Name = 'Switch-GitBranch'; Repo = $clone; Call = { Switch-GitBranch -Name 'side' -RepoPath $clone } }
        @{ Name = 'Sync-GitRemote'; Repo = $clone; Call = { Sync-GitRemote -RepoPath $clone } }
        @{ Name = 'Update-GitBranch'; Repo = $clone; Call = { Update-GitBranch -RepoPath $clone } }
    )

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    foreach ($row in $rows) {
        $before = Get-GitTestRepoState -Repo $row.Repo
        $run = Get-WhatIfOutput { Invoke-WhatIfCaller -Call $row.Call -WhatIf }
        Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $row.Repo) `
            -Message "$($row.Name) changes nothing when its caller was given -WhatIf"
        Assert-Equal -Expected 1 -Actual $run.Messages.Count -Message 'and says what it would have done'
    }

    #───────────────────────────────────────────────────────────────────────────
    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath $copy) `
        -Message 'Copy-GitRepository made no folder for the clone either'
}
finally {
    foreach ($path in $upstream, $clone, $ahead, $copy, $dirty, $merging, $rebasing) {
        Remove-GitTestRepo -Path $path
    }
}

exit (Complete-TestRun)
