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
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'second' -NoNewline
    git -C $repo commit --quiet -am 'second' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'uncommitted' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git clone --quiet --bare $repo $bare 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Reset-GitBranch -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf un-stages nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Reset (Mixed) to HEAD, unstaging the changes"" on target ""$repo""."
    ) -Actual $run.Messages -Message '-WhatIf names the repository, the mode and the ref, and what the mode does'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - a hard reset to an older commit
    $run = Get-WhatIfOutput { Reset-GitBranch -Ref 'HEAD~1' -Mode Hard -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Mode Hard discards nothing and moves no branch'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Mode Hard returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Reset (Hard) to HEAD~1, discarding uncommitted changes""" +
        " on target ""$repo""."
    ) -Actual $run.Messages -Message '-WhatIf with -Mode Hard says it would discard uncommitted changes'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = (git -C $bare for-each-ref) -join "`n"

    # Act - a soft reset in a bare repository, which has no working tree
    $run = Get-WhatIfOutput { Reset-GitBranch -Ref 'HEAD~1' -Mode Soft -RepoPath $bare -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual ((git -C $bare for-each-ref) -join "`n") `
        -Message '-WhatIf with -Mode Soft moves no branch'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Reset (Soft) to HEAD~1, keeping the changes staged"" on target ""$bare""."
    ) -Actual $run.Messages -Message '-WhatIf with -Mode Soft names a bare repository by its own folder'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Reset-GitBranch -Ref '-x' -RepoPath $repo -WhatIf } `
        -MessageLike "*'-x' is blank or starts with '-'*" -Message '-WhatIf still refuses a ref that starts with a dash'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a ref that names no commit
    Assert-Throws -ScriptBlock { Reset-GitBranch -Ref 'nope' -RepoPath $repo -WhatIf } `
        -MessageLike "Resetting to nope failed: 'nope' does not name a commit." `
        -Message '-WhatIf refuses a ref that names no commit'
    Assert-Throws -ScriptBlock { Reset-GitBranch -Ref 'nope' -RepoPath $repo } `
        -MessageLike "Resetting to nope failed: 'nope' does not name a commit." -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository, and a bare one for a mode
    # that needs a working tree
    Assert-Throws -ScriptBlock { Reset-GitBranch -RepoPath $folder -WhatIf } `
        -MessageLike "Resetting to HEAD failed: '$folder' is not inside a git working tree (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { Reset-GitBranch -RepoPath $folder } `
        -MessageLike "Resetting to HEAD failed: '$folder' is not inside a git working tree (*" `
        -Message 'and so does the real call'
    Assert-Throws -ScriptBlock { Reset-GitBranch -Mode Hard -RepoPath $bare -WhatIf } `
        -MessageLike "Resetting to HEAD failed: '$bare' is not inside a git working tree (*" `
        -Message '-WhatIf refuses a hard reset in a bare repository'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
    Remove-GitTestRepo -Path $bare
}

exit (Complete-TestRun)
