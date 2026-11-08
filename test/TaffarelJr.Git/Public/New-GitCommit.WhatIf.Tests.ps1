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
$folder = New-GitTestFolder
try {
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'staged' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { New-GitCommit -Message 'a message' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf commits nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Commit staged changes"" on target ""$repo"".") `
        -Actual $run.Messages -Message '-WhatIf names the repository, and not the message'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - -Amend, -NoEdit and -AllowEmpty
    $run = Get-WhatIfOutput { New-GitCommit -Amend -NoEdit -AllowEmpty -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Amend rewrites no commit'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Amend returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Amend the last commit, keeping its message, allowing an empty commit""" +
        " on target ""$repo""."
    ) -Actual $run.Messages -Message '-WhatIf with -Amend -NoEdit says it would amend, keeping the message'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -Amend with a new message
    $run = Get-WhatIfOutput { New-GitCommit 'new message' -Amend -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Amend the last commit, replacing its message"" on target ""$repo""."
    ) -Actual $run.Messages -Message '-WhatIf with -Amend and -Message says it would replace the message'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { New-GitCommit -RepoPath $repo -WhatIf } `
        -MessageLike '*Committing failed: -Message is required*' -Message '-WhatIf still refuses a missing message'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { New-GitCommit -Message 'm' -RepoPath $folder -WhatIf } `
        -MessageLike "Committing failed: '$folder' is not inside a git working tree (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { New-GitCommit -Message 'm' -RepoPath $folder } `
        -MessageLike "Committing failed: '$folder' is not inside a git working tree (*" `
        -Message 'and so does the real call'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
