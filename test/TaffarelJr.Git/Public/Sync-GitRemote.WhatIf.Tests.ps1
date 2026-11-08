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

$upstream = New-GitTestRepo
git -C $upstream tag v1 2>&1 | Out-Null
$repo = New-GitTestRepo -NoCommit
$folder = New-GitTestFolder
try {
    git -C $repo remote add origin $upstream 2>&1 | Out-Null
    git -C $repo config 'url.https://example.invalid/.insteadOf' 'short' 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Sync-GitRemote -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf fetches nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Fetch"" on target ""$repo remote origin"".") `
        -Actual $run.Messages -Message '-WhatIf names the repository and the remote'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - -Refspec, -Prune and -Tags, from a URL with a credential in it
    $run = Get-WhatIfOutput {
        Sync-GitRemote -Name 'https://user:s3cret@example.invalid/o/r.git' -Refspec 'main' -Prune -Tags `
            -RepoPath $repo -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Prune and -Tags fetches and prunes nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Refspec returns nothing'
    Assert-Equal -Expected @(
        'What if: Performing the operation "Fetch main, pruning stale remote-tracking refs, with every tag"' +
        " on target ""$repo remote https://***@example.invalid/o/r.git""."
    ) -Actual $run.Messages -Message '-WhatIf names the refspec and what -Prune and -Tags add, and hides the credential'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - a forced refspec
    $run = Get-WhatIfOutput { Sync-GitRemote -Refspec '+refs/heads/main:refs/heads/main' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with a forced refspec moves no branch'
    Assert-Equal -Expected @(
        'What if: Performing the operation "Fetch +refs/heads/main:refs/heads/main, allowing a forced update"' +
        " on target ""$repo remote origin""."
    ) -Actual $run.Messages -Message '-WhatIf says a forced refspec can force the update'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - every remote
    $run = Get-WhatIfOutput { Sync-GitRemote -All -Prune -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -All fetches nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Fetch every remote, pruning stale remote-tracking refs""" +
        " on target ""$repo""."
    ) -Actual $run.Messages -Message '-WhatIf with -All names the repository and every remote'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a name an insteadOf rule rewrites, and a path that exists
    $rewritten = Get-WhatIfOutput { Sync-GitRemote -Name 'short' -RepoPath $repo -WhatIf }
    $path = Get-WhatIfOutput { Sync-GitRemote -Name $upstream -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected @("What if: Performing the operation ""Fetch"" on target ""$repo remote short"".") `
        -Actual $rewritten.Messages -Message '-WhatIf accepts a name that an insteadOf rule rewrites'
    Assert-Equal -Expected @("What if: Performing the operation ""Fetch"" on target ""$repo remote $upstream"".") `
        -Actual $path.Messages -Message '-WhatIf accepts a path that exists'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Sync-GitRemote -Name '-x' -RepoPath $repo -WhatIf } `
        -MessageLike "*'-x' is blank or starts with '-'*" `
        -Message '-WhatIf still refuses a remote that starts with a dash'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a remote that is neither configured, nor a URL, nor a path
    Assert-Throws -ScriptBlock { Sync-GitRemote -Name 'nope' -RepoPath $repo -WhatIf } `
        -MessageLike "Fetching failed: 'nope' is not a remote, a URL, or a path that exists." `
        -Message '-WhatIf refuses a remote git could not find'
    Assert-Throws -ScriptBlock { Sync-GitRemote -Name 'nope' -RepoPath $repo } `
        -MessageLike "Fetching failed: 'nope' is not a remote, a URL, or a path that exists." `
        -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { Sync-GitRemote -RepoPath $folder -WhatIf } `
        -MessageLike "Fetching failed: '$folder' is not inside a git repository (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { Sync-GitRemote -RepoPath $folder } `
        -MessageLike "Fetching failed: '$folder' is not inside a git repository (*" `
        -Message 'and so does the real call'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
