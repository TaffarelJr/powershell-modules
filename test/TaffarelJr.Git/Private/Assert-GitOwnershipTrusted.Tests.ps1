#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force -PassThru
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

# GIT_TEST_ASSUME_DIFFERENT_OWNER, git's own switch for its ownership check,
# came with that check in 2.35.2, but git honors the safe.directory given on the
# command line, which the check under test relies on, only from 2.38.
$skipReason = Get-GitTestSkipReason -Minimum '2.38'
if ($skipReason) {
    exit (Skip-TestRun -Reason $skipReason)
}

$repo = New-GitTestRepo
$plain = New-GitTestFolder
$env:GIT_TEST_ASSUME_DIFFERENT_OWNER = '1'
try {
    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - the helper itself, after a command git refused
    Assert-Throws -ScriptBlock {
        & $module {
            param($r)
            Assert-GitOwnershipTrusted -Activity 'Reading' -Arguments @('rev-parse', '--git-dir') `
                -Message 'what git said' `
                -RepoPath $r
        } $repo
    } -MessageLike '*Reading failed: git refuses to use a repository another user owns. what git said*' `
        -Message 'A command that works once the repository is trusted was refused for its owner'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    & $module {
        param($p)
        Assert-GitOwnershipTrusted -Activity 'Reading' -Arguments @('rev-parse', '--git-dir') -Message '' -RepoPath $p
    } $plain
    $plainAnswer = Test-GitRepository -RepoPath $plain

    # Assert
    Assert-Equal -Expected $false -Actual $plainAnswer -Message 'A folder that is no repository is still just not one'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - the functions whose answer would otherwise be "no repository"
    Assert-Throws -ScriptBlock { Test-GitRepository -RepoPath $repo } `
        -MessageLike '*another user owns*dubious ownership*' `
        -Message 'Test-GitRepository throws rather than answering $false'
    Assert-Throws -ScriptBlock { Get-GitRepositoryRoot -RepoPath $repo } `
        -MessageLike '*another user owns*dubious ownership*' `
        -Message 'Get-GitRepositoryRoot throws rather than answering $null'
    Assert-Throws -ScriptBlock { Get-GitDirectory -RepoPath $repo } `
        -MessageLike '*another user owns*dubious ownership*' `
        -Message 'Get-GitDirectory throws rather than answering $null'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - and those whose answer would otherwise be "detached" or "no such ref"
    Assert-Throws -ScriptBlock { Get-GitBranch -RepoPath $repo } `
        -MessageLike '*Reading the current branch failed*dubious ownership*' `
        -Message 'Get-GitBranch throws rather than reading as a detached HEAD'
    Assert-Throws -ScriptBlock { Get-GitCommit -RepoPath $repo } `
        -MessageLike '*Resolving HEAD failed*dubious ownership*' `
        -Message 'Get-GitCommit throws rather than reading as no such commit'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - and those whose answer would otherwise be "not set", $null or $false
    Assert-Throws -ScriptBlock { Get-GitConfig -Name 'user.name' -RepoPath $repo } `
        -MessageLike '*another user owns*dubious ownership*' `
        -Message 'Get-GitConfig throws rather than reading a key the repository sets as not set'
    Assert-Throws -ScriptBlock { Get-GitDefaultBranch -RepoPath $repo } `
        -MessageLike '*Reading the default branch failed (exit 128)*dubious ownership*' `
        -Message 'Get-GitDefaultBranch throws rather than answering $null'
    Assert-Throws -ScriptBlock { Test-GitRebaseInProgress -RepoPath $repo } `
        -MessageLike '*another user owns*dubious ownership*' `
        -Message 'Test-GitRebaseInProgress throws rather than answering $false'
    Assert-Throws -ScriptBlock { Get-GitConflict -RepoPath $repo } `
        -MessageLike '*Reading conflicted paths failed*dubious ownership*' `
        -Message 'Get-GitConflict names the ownership problem'
    Assert-Throws -ScriptBlock { Restore-GitStash -RepoPath $repo } `
        -MessageLike '*Reading conflicted paths failed*dubious ownership*' `
        -Message 'and so does Restore-GitStash, which asks it first'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $missing = Join-Path $plain 'missing'

    # Act
    & $module {
        param($p)
        function Invoke-GitCommand {
            throw 'git was asked again'
        }

        Assert-GitOwnershipTrusted -Activity 'Reading' -Arguments @('rev-parse', '--git-dir') -Message '' -RepoPath $p
    } $missing
    $missingAnswer = Test-GitRepository -RepoPath $missing

    # Assert
    Assert-Equal -Expected $false -Actual $missingAnswer `
        -Message 'A folder that does not exist is not asked about twice, and is no repository'
}
finally {
    Remove-Item -LiteralPath Env:GIT_TEST_ASSUME_DIFFERENT_OWNER
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $plain
}

exit (Complete-TestRun)
