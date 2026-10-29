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
$bare = Join-Path ([System.IO.Path]::GetTempPath()) "git-bare-$([Guid]::NewGuid())"
try {
    git -C $repo branch taken 2>&1 | Out-Null
    git clone --quiet --bare $repo $bare 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { New-GitBranch -Name 'feature' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf creates no branch'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Create branch"" on target ""$repo branch feature""."
    ) -Actual $run.Messages -Message '-WhatIf names the repository and the branch it would create'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - with -StartPoint and -Switch
    $run = Get-WhatIfOutput { New-GitBranch 'feature' -StartPoint 'HEAD' -Switch -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Switch neither creates nor checks out a branch'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Switch returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Create and switch to branch, starting at HEAD""" +
        " on target ""$repo branch feature""."
    ) -Actual $run.Messages -Message '-WhatIf with -Switch says it would switch too, and where the branch starts'

    #───────────────────────────────────────────────────────────────────────────
    # Act - in a bare repository, which has no working tree to switch
    $run = Get-WhatIfOutput { New-GitBranch -Name 'feature' -RepoPath $bare -WhatIf }

    # Assert
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Create branch"" on target ""$bare branch feature""."
    ) -Actual $run.Messages -Message '-WhatIf names a bare repository by its own folder'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { New-GitBranch -Name '-x' -RepoPath $repo -WhatIf } `
        -MessageLike "*'-x' is blank or starts with '-'*" `
        -Message '-WhatIf still refuses a name that starts with a dash'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a branch that already exists
    Assert-Throws -ScriptBlock { New-GitBranch -Name 'taken' -RepoPath $repo -WhatIf } `
        -MessageLike "Creating branch taken failed: a branch named 'taken' already exists." `
        -Message '-WhatIf refuses a branch that already exists'
    Assert-Throws -ScriptBlock { New-GitBranch -Name 'taken' -RepoPath $repo } `
        -MessageLike "Creating branch taken failed: a branch named 'taken' already exists." `
        -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a name git would refuse
    Assert-Throws -ScriptBlock { New-GitBranch -Name 'a..b' -RepoPath $repo -WhatIf } `
        -MessageLike "Creating branch a..b failed: 'a..b' is not a valid branch name." `
        -Message '-WhatIf refuses a malformed name'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - HEAD, which check-ref-format allows but git refuses as a branch
    Assert-Throws -ScriptBlock { New-GitBranch -Name 'HEAD' -RepoPath $repo -WhatIf } `
        -MessageLike "Creating branch HEAD failed: 'HEAD' is not a valid branch name." `
        -Message '-WhatIf refuses HEAD as a branch name'
    Assert-Throws -ScriptBlock { New-GitBranch -Name 'HEAD' -RepoPath $repo } `
        -MessageLike "Creating branch HEAD failed: 'HEAD' is not a valid branch name." `
        -Message 'and so does the real call, in the same words'
    Assert-Throws -ScriptBlock { New-GitBranch -Name 'a..b' -RepoPath $repo } `
        -MessageLike "Creating branch a..b failed: 'a..b' is not a valid branch name." `
        -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a start point that names no commit
    Assert-Throws -ScriptBlock { New-GitBranch -Name 'feature' -StartPoint 'nope' -RepoPath $repo -WhatIf } `
        -MessageLike "Creating branch feature failed: 'nope' does not name a commit." `
        -Message '-WhatIf refuses a start point that names no commit'
    Assert-Throws -ScriptBlock { New-GitBranch -Name 'feature' -StartPoint 'nope' -RepoPath $repo } `
        -MessageLike "Creating branch feature failed: 'nope' does not name a commit." `
        -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { New-GitBranch -Name 'feature' -RepoPath $folder -WhatIf } `
        -MessageLike "Creating branch feature failed: '$folder' is not inside a git repository (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { New-GitBranch -Name 'feature' -RepoPath $folder } `
        -MessageLike "Creating branch feature failed: '$folder' is not inside a git repository (*" `
        -Message 'and so does the real call'
    Assert-Throws -ScriptBlock { New-GitBranch -Name 'feature' -Switch -RepoPath $bare -WhatIf } `
        -MessageLike "Creating branch feature failed: '$bare' is not inside a git working tree (*" `
        -Message 'and -Switch refuses a bare repository'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
    Remove-GitTestRepo -Path $bare
}

exit (Complete-TestRun)
