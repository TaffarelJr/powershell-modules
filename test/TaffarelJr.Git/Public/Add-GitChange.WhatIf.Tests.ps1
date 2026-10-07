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
    New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'new' -NoNewline
    $a = Join-Path $repo 'a.txt'
    $b = Join-Path $repo 'b.txt'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - the whole working tree, from a subfolder
    $run = Get-WhatIfOutput { Add-GitChange -RepoPath (Join-Path $repo 'sub') -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf stages nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Stage all changes"" on target ""$repo"".") `
        -Actual $run.Messages -Message '-WhatIf names the root of the repository it would stage everything in'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - named paths, one relative to the root and one to -RepoPath
    $run = Get-WhatIfOutput { Add-GitChange -Path 'a.txt', '..\b.txt' -RepoPath (Join-Path $repo 'sub') -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Path stages nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Path returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Stage changes"" on target ""$a, $b"".") `
        -Actual $run.Messages -Message '-WhatIf with -Path names the full path of each'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - two paths from the pipeline, staged together at the end
    $run = Get-WhatIfOutput { 'a.txt', 'b.txt' | Add-GitChange -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf stages neither piped path'
    Assert-Equal -Expected @("What if: Performing the operation ""Stage changes"" on target ""$a, $b"".") `
        -Actual $run.Messages -Message '-WhatIf reports the piped paths once, as the one git call they make'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitChange -Path 'src/../../x.txt' -RepoPath $repo -WhatIf } `
        -MessageLike "*Staging changes failed: -Path 'src/../../x.txt' climbs above the repository root*" `
        -Message '-WhatIf still refuses a path that climbs above the root'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { Add-GitChange -RepoPath $folder -WhatIf } `
        -MessageLike "Staging changes failed: '$folder' is not inside a git working tree (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { Add-GitChange -RepoPath $folder } `
        -MessageLike "Staging changes failed: '$folder' is not inside a git working tree (*" `
        -Message 'and so does the real call'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
