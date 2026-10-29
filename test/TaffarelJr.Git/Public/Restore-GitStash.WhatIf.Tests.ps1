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
$none = New-GitTestRepo
try {
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'first stash' -NoNewline
    git -C $repo stash push --quiet 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'second stash' -NoNewline
    git -C $repo stash push --quiet 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Restore-GitStash -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf neither applies nor drops the stash'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing, not a Conflict object'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Restore stash, then drop it unless it conflicts""" +
        " on target ""$repo stash@{0}""."
    ) -Actual $run.Messages -Message '-WhatIf names the repository and the stash it would restore'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - an older stash, by -Index
    $run = Get-WhatIfOutput { Restore-GitStash -Index 1 -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Index restores nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Index returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Restore stash, then drop it unless it conflicts""" +
        " on target ""$repo stash@{1}""."
    ) -Actual $run.Messages -Message '-WhatIf with -Index names that stash'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Restore-GitStash -Index -1 -RepoPath $repo -WhatIf } `
        -MessageLike '*Cannot validate argument on parameter ''Index''*' `
        -Message '-WhatIf still refuses a negative index'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a stash that does not exist
    Assert-Throws -ScriptBlock { Restore-GitStash -Index 2 -RepoPath $repo -WhatIf } `
        -MessageLike 'Restoring the stash failed: there is no stash@{2}.' `
        -Message '-WhatIf refuses an index past the last stash'
    Assert-Throws -ScriptBlock { Restore-GitStash -Index 2 -RepoPath $repo } `
        -MessageLike 'Restoring the stash failed: there is no stash@{2}.' -Message 'and so does the real call'
    Assert-Throws -ScriptBlock { Restore-GitStash -RepoPath $none -WhatIf } `
        -MessageLike 'Restoring the stash failed: there is no stash@{0}.' `
        -Message '-WhatIf refuses a repository with no stash at all'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $none
}

exit (Complete-TestRun)
