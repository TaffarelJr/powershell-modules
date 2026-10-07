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

$remote = New-GitTestRepo -NoCommit
git -C $remote 'config' 'receive.denyCurrentBranch' 'ignore' 2>&1 | Out-Null
$repo = New-GitTestRepo
try {
    git -C $repo remote add origin $remote 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo
    $remoteBefore = Get-GitTestRepoState -Repo $remote

    # Act
    $run = Get-WhatIfOutput { Push-GitCommit -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $remoteBefore -Actual (Get-GitTestRepoState -Repo $remote) `
        -Message '-WhatIf sends nothing to the remote'
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf changes nothing locally'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing, not $true or $false'
    Assert-Equal -Expected @("What if: Performing the operation ""Push to origin"" on target ""$repo branch main"".") `
        -Actual $run.Messages -Message '-WhatIf names the repository, the current branch and the remote'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo
    $remoteBefore = Get-GitTestRepoState -Repo $remote

    # Act - -Branch, -Remote, -SetUpstream and -Force
    $run = Get-WhatIfOutput {
        Push-GitCommit -Branch 'main' -Remote 'origin' -SetUpstream -Force -RepoPath $repo -WhatIf
    }

    # Assert
    Assert-Equal -Expected $remoteBefore -Actual (Get-GitTestRepoState -Repo $remote) `
        -Message '-WhatIf with -Force sends nothing'
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -SetUpstream sets no upstream'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Force returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Force push, with a lease, to origin, setting it as the upstream""" +
        " on target ""$repo branch main""."
    ) -Actual $run.Messages -Message '-WhatIf with -Force says it would force, with a lease, and set the upstream'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - -ForceWithoutLease, to a URL with a credential in it
    $run = Get-WhatIfOutput {
        Push-GitCommit -Remote 'https://user:s3cret@example.invalid/o/r.git' -ForceWithoutLease -RepoPath $repo -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -ForceWithoutLease changes nothing'
    Assert-Equal -Expected @(
        'What if: Performing the operation "Force push to https://***@example.invalid/o/r.git"' +
        " on target ""$repo branch main""."
    ) -Actual $run.Messages -Message '-WhatIf hides the credential in a remote URL'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a remote given as a path to a repository
    $run = Get-WhatIfOutput { Push-GitCommit -Remote $remote -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected @("What if: Performing the operation ""Push to $remote"" on target ""$repo branch main"".") `
        -Actual $run.Messages -Message '-WhatIf accepts a path that exists as the remote'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a remote that is neither configured, nor a URL, nor a path
    Assert-Throws -ScriptBlock { Push-GitCommit -Remote 'nope' -RepoPath $repo -WhatIf } `
        -MessageLike "Pushing failed: 'nope' is not a remote, a URL, or a path that exists." `
        -Message '-WhatIf refuses a remote git could not find'
    Assert-Throws -ScriptBlock { Push-GitCommit -Remote 'nope' -RepoPath $repo } `
        -MessageLike "Pushing failed: 'nope' is not a remote, a URL, or a path that exists." `
        -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    git -C $repo checkout -q --detach 2>&1 | Out-Null

    # Act / Assert
    Assert-Throws -ScriptBlock { Push-GitCommit -RepoPath $repo -WhatIf } `
        -MessageLike '*Pushing failed: HEAD is detached*pass -Branch*' `
        -Message '-WhatIf still refuses a detached HEAD'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $remote
}

exit (Complete-TestRun)
