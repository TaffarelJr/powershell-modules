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
    git -C $repo branch feature 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Switch-GitBranch -Name 'feature' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf checks nothing out'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Switch to branch"" on target ""$repo branch feature""."
    ) -Actual $run.Messages -Message '-WhatIf names the repository and the branch it would switch to'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - with -Create and -StartPoint
    $run = Get-WhatIfOutput { Switch-GitBranch 'made' -Create -StartPoint 'HEAD' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Create neither creates nor checks out the branch'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Create returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Create and switch to branch, starting at HEAD""" +
        " on target ""$repo branch made""."
    ) -Actual $run.Messages -Message '-WhatIf with -Create says it would create the branch, and from where'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -Create without -StartPoint
    $run = Get-WhatIfOutput { Switch-GitBranch 'new-one' -Create -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Create and switch to branch""" +
        " on target ""$repo branch new-one""."
    ) -Actual $run.Messages -Message '-WhatIf with -Create and no start point names no start point'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Switch-GitBranch 'feature' -Create -RepoPath $repo -WhatIf } `
        -MessageLike "Switching to feature failed: a branch named 'feature' already exists.*" `
        -Message '-WhatIf with -Create still refuses a branch that exists'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'nope' -RepoPath $repo -WhatIf } `
        -MessageLike "*Switching to nope failed: there is no branch named 'nope'*" `
        -Message '-WhatIf still refuses a branch that does not exist'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - -Create with a name or a start point git would refuse
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'a..b' -Create -RepoPath $repo -WhatIf } `
        -MessageLike "Switching to a..b failed: 'a..b' is not a valid branch name." `
        -Message '-WhatIf refuses a malformed name to create'
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'a..b' -Create -RepoPath $repo } `
        -MessageLike "Switching to a..b failed: 'a..b' is not a valid branch name." -Message 'and so does the real call'
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'x' -Create -StartPoint 'nope' -RepoPath $repo -WhatIf } `
        -MessageLike "Switching to x failed: 'nope' does not name a commit." `
        -Message '-WhatIf refuses a start point that names no commit'
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'x' -Create -StartPoint 'nope' -RepoPath $repo } `
        -MessageLike "Switching to x failed: 'nope' does not name a commit." -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'x' -Create -RepoPath $folder -WhatIf } `
        -MessageLike "Switching to x failed: '$folder' is not inside a git working tree (*" `
        -Message '-WhatIf with -Create refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { Switch-GitBranch -Name 'x' -Create -RepoPath $folder } `
        -MessageLike "Switching to x failed: '$folder' is not inside a git working tree (*" `
        -Message 'and so does the real call'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
