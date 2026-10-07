#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$remote = New-GitTestRepo -NoCommit
git -C $remote 'config' 'receive.denyCurrentBranch' 'ignore' 2>&1 | Out-Null
$repo = New-GitTestRepo
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-GitRemote -Name 'origin' -Url $remote -RepoPath $repo

    # Act - the first push, with -SetUpstream
    $sent = Push-GitCommit -SetUpstream -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $sent -Message 'A push that actually sends commits reports true'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'HEAD' -RepoPath $repo) -Actual (Resolve-GitRef -Ref 'main' -RepoPath $remote) `
        -Message 'The remote now has the pushed commit'

    #───────────────────────────────────────────────────────────────────────────
    # Act - pushing again with nothing new
    $sentAgain = Push-GitCommit -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual $sentAgain -Message 'A push with nothing new reports false'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - the remote moves ahead independently
    Set-Content -LiteralPath (Join-Path $remote 'remote-only.txt') -Value 'x' -NoNewline
    git -C $remote add -A 2>&1 | Out-Null
    git -C $remote commit --quiet -m 'remote-only change' 2>&1 | Out-Null

    Set-Content -LiteralPath (Join-Path $repo 'local-only.txt') -Value 'y' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'local-only change' 2>&1 | Out-Null

    # Act / Assert - a push that would overwrite remote history is refused
    Assert-Throws -ScriptBlock { Push-GitCommit -RepoPath $repo } -Message 'A diverged push is refused without -Force'

    # Act - -ForceWithoutLease pushes anyway
    $forced = Push-GitCommit -ForceWithoutLease -RepoPath $repo

    # Assert
    Assert-Equal -Expected $true -Actual $forced -Message '-ForceWithoutLease overwrites the diverged remote branch'
    Assert-Equal -Expected (Resolve-GitRef -Ref 'HEAD' -RepoPath $repo) -Actual (Resolve-GitRef -Ref 'main' -RepoPath $remote) `
        -Message 'The remote now matches the local branch'
}
finally {
    Remove-GitTestRepo -Path $remote
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
