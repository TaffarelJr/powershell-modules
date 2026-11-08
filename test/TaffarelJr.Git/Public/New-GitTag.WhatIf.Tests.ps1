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
$empty = New-GitTestRepo -NoCommit
$folder = New-GitTestFolder
try {
    git -C $repo tag taken 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { New-GitTag -Name 'v1' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf creates no tag'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Create tag"" on target ""$repo tag v1"".") `
        -Actual $run.Messages -Message '-WhatIf names the repository and the tag it would create'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - an annotated tag on a named commit
    $run = Get-WhatIfOutput { New-GitTag 'v1' -Ref 'HEAD' -Message 'release notes' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Ref and -Message creates no tag'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Message returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Create annotated tag, at HEAD"" on target ""$repo tag v1""."
    ) -Actual $run.Messages -Message '-WhatIf with -Message names the kind of tag and where, and not the message'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { New-GitTag -Name '-x' -RepoPath $repo -WhatIf } `
        -MessageLike "*'-x' is blank or starts with '-'*" `
        -Message '-WhatIf still refuses a name that starts with a dash'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a tag that already exists
    Assert-Throws -ScriptBlock { New-GitTag -Name 'taken' -RepoPath $repo -WhatIf } `
        -MessageLike "Creating tag taken failed: a tag named 'taken' already exists." `
        -Message '-WhatIf refuses a tag that already exists'
    Assert-Throws -ScriptBlock { New-GitTag -Name 'taken' -RepoPath $repo } `
        -MessageLike "Creating tag taken failed: a tag named 'taken' already exists." `
        -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a name git would refuse
    Assert-Throws -ScriptBlock { New-GitTag -Name 'a b' -RepoPath $repo -WhatIf } `
        -MessageLike "Creating tag a b failed: 'a b' is not a valid tag name." `
        -Message '-WhatIf refuses a malformed name'
    Assert-Throws -ScriptBlock { New-GitTag -Name 'a b' -RepoPath $repo } `
        -MessageLike "Creating tag a b failed: 'a b' is not a valid tag name." -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - nothing to tag: a -Ref that names nothing, or no commit yet
    Assert-Throws -ScriptBlock { New-GitTag -Name 'v1' -Ref 'nope' -RepoPath $repo -WhatIf } `
        -MessageLike "Creating tag v1 failed: 'nope' does not name a revision." `
        -Message '-WhatIf refuses a -Ref that names nothing'
    Assert-Throws -ScriptBlock { New-GitTag -Name 'v1' -Ref 'nope' -RepoPath $repo } `
        -MessageLike "Creating tag v1 failed: 'nope' does not name a revision." -Message 'and so does the real call'
    Assert-Throws -ScriptBlock { New-GitTag -Name 'v1' -RepoPath $empty -WhatIf } `
        -MessageLike "Creating tag v1 failed: 'HEAD' does not name a revision." `
        -Message '-WhatIf refuses a repository with no commit to tag'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { New-GitTag -Name 'v1' -RepoPath $folder -WhatIf } `
        -MessageLike "Creating tag v1 failed: '$folder' is not inside a git repository (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { New-GitTag -Name 'v1' -RepoPath $folder } `
        -MessageLike "Creating tag v1 failed: '$folder' is not inside a git repository (*" `
        -Message 'and so does the real call'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $empty
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
