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
$idle = New-GitTestRepo
$folder = New-GitTestFolder
try {
    git -C $repo checkout -q -b feature 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'feature' -NoNewline
    git -C $repo commit --quiet -am 'feature change' 2>&1 | Out-Null
    git -C $repo checkout -q main 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'main' -NoNewline
    git -C $repo commit --quiet -am 'main change' 2>&1 | Out-Null
    git -C $repo checkout -q feature 2>&1 | Out-Null
    git -C $repo rebase main 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Stop-GitRebase -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf leaves the rebase paused where it was'
    Assert-Equal -Expected $true -Actual (Test-GitRebaseInProgress -RepoPath $repo) `
        -Message '-WhatIf abandons no rebase'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Abort the rebase"" on target ""$repo"".") `
        -Actual $run.Messages -Message '-WhatIf names the repository'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo
    Push-Location -LiteralPath $repo

    # Act - from the current location, with no -RepoPath
    try {
        $run = Get-WhatIfOutput { Stop-GitRebase -WhatIf }
    }
    finally {
        Pop-Location
    }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf without -RepoPath abandons nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Abort the rebase"" on target ""$repo"".") `
        -Actual $run.Messages -Message '-WhatIf without -RepoPath names the current location'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - no rebase under way
    Assert-Throws -ScriptBlock { Stop-GitRebase -RepoPath $idle -WhatIf } `
        -MessageLike "Aborting the rebase failed: no rebase is in progress in '$idle'." `
        -Message '-WhatIf refuses a repository with no rebase under way'
    Assert-Throws -ScriptBlock { Stop-GitRebase -RepoPath $idle } `
        -MessageLike "Aborting the rebase failed: no rebase is in progress in '$idle'." `
        -Message 'and so does the real call'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { Stop-GitRebase -RepoPath $folder -WhatIf } `
        -MessageLike "Aborting the rebase failed: '$folder' is not inside a git working tree (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { Stop-GitRebase -RepoPath $folder } `
        -MessageLike "Aborting the rebase failed: '$folder' is not inside a git working tree (*" `
        -Message 'and so does the real call'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $idle
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
