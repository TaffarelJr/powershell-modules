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
$repo = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
$folder = New-GitTestFolder
try {
    git clone --quiet $upstream $repo 2>&1 | Out-Null
    git -C $repo config user.name 'Test' 2>&1 | Out-Null
    git -C $repo config user.email 'test@example.com' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $upstream 'upstream.txt') -Value 'upstream' -NoNewline
    git -C $upstream add -A 2>&1 | Out-Null
    git -C $upstream commit --quiet -m 'upstream change' 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Update-GitBranch -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf pulls nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing, not a Conflict object'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Pull branch main from remote origin, merging"" on target ""$repo""."
    ) -Actual $run.Messages `
        -Message '-WhatIf names the upstream branch by its short name, the remote and the repository'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - -Branch, -Remote and -Rebase
    $run = Get-WhatIfOutput { Update-GitBranch -Branch 'main' -Remote 'origin' -Rebase -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Rebase pulls nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Rebase returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Pull branch main from remote origin, rebasing"" on target ""$repo""."
    ) -Actual $run.Messages -Message '-WhatIf with -Rebase says it would rebase'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Update-GitBranch -FastForwardOnly -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -FastForwardOnly pulls nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Pull branch main from remote origin, fast-forwarding only""" +
        " on target ""$repo""."
    ) -Actual $run.Messages -Message '-WhatIf with -FastForwardOnly says it would only fast-forward'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - from a URL with a credential in it
    $run = Get-WhatIfOutput {
        Update-GitBranch -Branch 'main' -Remote 'https://u:s3cret@h.invalid/o.git' -RepoPath $repo -WhatIf
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf from a URL pulls nothing'
    Assert-Equal -Expected @(
        'What if: Performing the operation "Pull branch main from remote https://***@h.invalid/o.git, merging"' +
        " on target ""$repo""."
    ) -Actual $run.Messages -Message '-WhatIf hides the credential in a remote URL'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a remote that is neither configured, nor a URL, nor a path
    Assert-Throws -ScriptBlock { Update-GitBranch -Branch 'main' -Remote 'nope' -RepoPath $repo -WhatIf } `
        -MessageLike "Pulling failed: 'nope' is not a remote, a URL, or a path that exists." `
        -Message '-WhatIf refuses a remote git could not find'
    Assert-Throws -ScriptBlock { Update-GitBranch -Branch 'main' -Remote 'nope' -RepoPath $repo } `
        -MessageLike "Pulling failed: 'nope' is not a remote, a URL, or a path that exists." `
        -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { Update-GitBranch -Branch 'main' -RepoPath $folder -WhatIf } `
        -MessageLike "Pulling failed: '$folder' is not inside a git working tree (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { Update-GitBranch -Branch 'main' -RepoPath $folder } `
        -MessageLike "Pulling failed: '$folder' is not inside a git working tree (*" `
        -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    git -C $repo checkout -q --detach 2>&1 | Out-Null

    # Act / Assert
    Assert-Throws -ScriptBlock { Update-GitBranch -RepoPath $repo -WhatIf } `
        -MessageLike '*Pulling failed: HEAD is detached*pass -Branch*' -Message '-WhatIf still refuses a detached HEAD'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $upstream
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
