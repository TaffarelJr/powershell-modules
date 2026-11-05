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
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'untracked.txt') -Value 'new' -NoNewline

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Save-GitStash -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf stashes nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing, not $true or $false'
    Assert-Equal -Expected @("What if: Performing the operation ""Stash changes"" on target ""$repo"".") `
        -Actual $run.Messages -Message '-WhatIf names the repository'

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $verbose = @(Save-GitStash -RepoPath $repo -WhatIf -Verbose 4>&1 |
            Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } | ForEach-Object Message)

    # Assert
    Assert-Equal -Expected @() -Actual @($verbose | Where-Object { $_ -like '*refs/stash*' }) `
        -Message '-WhatIf does not read the stash, which only the real run compares before and after'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - with -Message and -IncludeUntracked
    $run = Get-WhatIfOutput { Save-GitStash -Message 'a label' -IncludeUntracked -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -IncludeUntracked stashes nothing, untracked files included'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -IncludeUntracked returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Stash changes, including untracked files"" on target ""$repo""."
    ) -Actual $run.Messages -Message '-WhatIf with -Message names the repository, and not the label'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Save-GitStash -RepoPath $folder -WhatIf } `
        -MessageLike "Stashing changes failed: '$folder' is not inside a git working tree (*" `
        -Message '-WhatIf still refuses a folder that is no repository'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
