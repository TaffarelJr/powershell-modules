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
    git -C $repo remote add origin 'https://example.invalid/o/r.git' 2>&1 | Out-Null
    git -C $repo remote add upstream 'https://example.invalid/u/r.git' 2>&1 | Out-Null

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Remove-GitRemote -Name 'origin' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf removes no remote'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Remove remote"" on target ""$repo remote origin"".") `
        -Actual $run.Messages -Message '-WhatIf names the repository and the remote it would remove'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - two remotes from the pipeline, and one that does not exist
    $run = Get-WhatIfOutput { 'origin', 'missing', 'upstream' | Remove-GitRemote -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf removes neither piped remote'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Remove remote"" on target ""$repo remote origin""."
        "What if: Performing the operation ""Remove remote"" on target ""$repo remote upstream""."
    ) -Actual $run.Messages -Message '-WhatIf reports each remote it would remove, and not a missing one'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Remove-GitRemote -Name '-x' -RepoPath $repo -WhatIf } `
        -MessageLike "*'-x' is blank or starts with '-'*" `
        -Message '-WhatIf still refuses a name that starts with a dash'
    Assert-Throws -ScriptBlock { Remove-GitRemote -Name 'origin' -RepoPath $folder -WhatIf } `
        -MessageLike '*Listing remotes failed*not a git repository*' `
        -Message '-WhatIf still refuses a folder that is no repository'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
