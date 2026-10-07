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
    git -C $repo branch merged 2>&1 | Out-Null
    git -C $repo branch other 2>&1 | Out-Null
    git -C $repo tag only-a-tag 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Remove-GitBranch -Name 'merged' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf deletes no branch'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Delete branch"" on target ""$repo branch merged"".") `
        -Actual $run.Messages -Message '-WhatIf names the repository and the branch it would delete'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - with -Force too
    $run = Get-WhatIfOutput { Remove-GitBranch 'merged' -Force -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Force deletes no branch'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Force returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Delete branch, even if not fully merged""" +
        " on target ""$repo branch merged""."
    ) -Actual $run.Messages -Message '-WhatIf with -Force says it would delete an unmerged branch too'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - two branches from the pipeline
    $run = Get-WhatIfOutput { 'merged', 'other' | Remove-GitBranch -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf deletes neither piped branch'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Delete branch"" on target ""$repo branch merged""."
        "What if: Performing the operation ""Delete branch"" on target ""$repo branch other""."
    ) -Actual $run.Messages -Message '-WhatIf reports each piped branch'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Remove-GitBranch -Name '-x' -RepoPath $repo -WhatIf } `
        -MessageLike "*'-x' is blank or starts with '-'*" `
        -Message '-WhatIf still refuses a name that starts with a dash'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a branch that does not exist, though a tag has the name
    Assert-Throws -ScriptBlock { Remove-GitBranch -Name 'only-a-tag' -RepoPath $repo -WhatIf } `
        -MessageLike "Deleting branch only-a-tag failed: there is no branch named 'only-a-tag'." `
        -Message '-WhatIf refuses a branch that does not exist'
    Assert-Throws -ScriptBlock { Remove-GitBranch -Name 'only-a-tag' -RepoPath $repo } `
        -MessageLike "Deleting branch only-a-tag failed: there is no branch named 'only-a-tag'." `
        -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { Remove-GitBranch -Name 'merged' -RepoPath $folder -WhatIf } `
        -MessageLike "Deleting branch merged failed: '$folder' is not inside a git repository (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { Remove-GitBranch -Name 'merged' -RepoPath $folder } `
        -MessageLike "Deleting branch merged failed: '$folder' is not inside a git repository (*" `
        -Message 'and so does the real call'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
