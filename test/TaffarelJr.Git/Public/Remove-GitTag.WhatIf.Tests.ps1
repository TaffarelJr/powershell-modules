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
    git -C $repo tag v1 2>&1 | Out-Null
    git -C $repo tag v2 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Remove-GitTag -Name 'v1' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf deletes no tag'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Delete tag"" on target ""$repo tag v1"".") `
        -Actual $run.Messages -Message '-WhatIf names the repository and the tag it would delete'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - two tags from the pipeline
    $run = Get-WhatIfOutput { 'v1', 'v2' | Remove-GitTag -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf deletes neither piped tag'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Delete tag"" on target ""$repo tag v1""."
        "What if: Performing the operation ""Delete tag"" on target ""$repo tag v2""."
    ) -Actual $run.Messages -Message '-WhatIf reports each piped tag'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Remove-GitTag -Name '-x' -RepoPath $repo -WhatIf } `
        -MessageLike "*'-x' is blank or starts with '-'*" `
        -Message '-WhatIf still refuses a name that starts with a dash'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a tag that does not exist, though a branch has the name
    Assert-Throws -ScriptBlock { Remove-GitTag -Name 'main' -RepoPath $repo -WhatIf } `
        -MessageLike "Deleting tag main failed: there is no tag named 'main'." `
        -Message '-WhatIf refuses a tag that does not exist'
    Assert-Throws -ScriptBlock { Remove-GitTag -Name 'main' -RepoPath $repo } `
        -MessageLike "Deleting tag main failed: there is no tag named 'main'." -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { Remove-GitTag -Name 'v1' -RepoPath $folder -WhatIf } `
        -MessageLike "Deleting tag v1 failed: '$folder' is not inside a git repository (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { Remove-GitTag -Name 'v1' -RepoPath $folder } `
        -MessageLike "Deleting tag v1 failed: '$folder' is not inside a git repository (*" `
        -Message 'and so does the real call'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
