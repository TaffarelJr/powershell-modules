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
    git -C $repo checkout -q -b feature 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'feature.txt') -Value 'feature' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'feature change' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'main.txt') -Value 'main' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'main change' 2>&1 | Out-Null
    git -C $repo checkout -q feature 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Start-GitRebase -Ref 'main' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf replays nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing, not a Conflict object'
    Assert-Equal -Expected @("What if: Performing the operation ""Rebase onto main"" on target ""$repo"".") `
        -Actual $run.Messages -Message '-WhatIf names the ref and the repository'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Start-GitRebase -Ref '-x' -RepoPath $repo -WhatIf } `
        -MessageLike "*'-x' is blank or starts with '-'*" -Message '-WhatIf still refuses a ref that starts with a dash'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a ref that names no commit
    Assert-Throws -ScriptBlock { Start-GitRebase -Ref 'nope' -RepoPath $repo -WhatIf } `
        -MessageLike "Rebasing onto nope failed: 'nope' does not name a commit." `
        -Message '-WhatIf refuses a ref that names no commit'
    Assert-Throws -ScriptBlock { Start-GitRebase -Ref 'nope' -RepoPath $repo } `
        -MessageLike "Rebasing onto nope failed: 'nope' does not name a commit." -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { Start-GitRebase -Ref 'main' -RepoPath $folder -WhatIf } `
        -MessageLike "Rebasing onto main failed: '$folder' is not inside a git working tree (*" `
        -Message '-WhatIf refuses a folder that is no repository'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
