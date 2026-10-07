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

$repo = New-GitTestPathRepo -Path 'b.txt', 'src/x.txt'
$folder = New-GitTestFolder
try {
    $a = Join-Path $repo 'a.txt'
    $b = Join-Path $repo 'b.txt'
    $src = Join-Path $repo 'src'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Remove-GitFile -Path 'a.txt' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf deletes nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @("What if: Performing the operation ""Delete"" on target ""$a"".") `
        -Actual $run.Messages -Message '-WhatIf names the full path of the file it would delete'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - two files from the pipeline
    $run = Get-WhatIfOutput { 'a.txt', 'b.txt' | Remove-GitFile -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf deletes neither piped file'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Delete"" on target ""$a""."
        "What if: Performing the operation ""Delete"" on target ""$b""."
    ) -Actual $run.Messages -Message '-WhatIf reports each piped file'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    Set-Content -LiteralPath (Join-Path $repo 'src/x.txt') -Value 'uncommitted' -NoNewline
    $before = Get-GitTestRepoState -Repo $repo

    # Act - a folder with uncommitted work, with -Recurse and -Force
    $run = Get-WhatIfOutput { Remove-GitFile 'src' -Recurse -Force -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Recurse and -Force deletes nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Recurse returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Delete, recursively, even with uncommitted changes"" on target ""$src""."
    ) -Actual $run.Messages -Message '-WhatIf with -Recurse and -Force names the folder and says what each allows'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Remove-GitFile -Path 'src/../../x.txt' -RepoPath $repo -WhatIf } `
        -MessageLike "*-Path 'src/../../x.txt' climbs above the repository root*" `
        -Message '-WhatIf still refuses a path that climbs above the root'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - a folder that is no repository
    Assert-Throws -ScriptBlock { Remove-GitFile -Path 'a.txt' -RepoPath $folder -WhatIf } `
        -MessageLike "Deleting a.txt failed: '$folder' is not inside a git working tree (*" `
        -Message '-WhatIf refuses a folder that is no repository'
    Assert-Throws -ScriptBlock { Remove-GitFile -Path 'a.txt' -RepoPath $folder } `
        -MessageLike "Deleting a.txt failed: '$folder' is not inside a git working tree (*" `
        -Message 'and so does the real call'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
