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

$repo = New-GitTestPathRepo -Path 'b.txt'
$folder = New-GitTestFolder
try {
    $a = Join-Path $repo 'a.txt'
    $b = Join-Path $repo 'b.txt'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act
    $run = Get-WhatIfOutput { Move-GitFile -Path 'a.txt' -Destination 'moved.txt' -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) -Message '-WhatIf moves nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Move to $(Join-Path $repo 'moved.txt')"" on target ""$a""."
    ) -Actual $run.Messages -Message '-WhatIf names the full path of the file and of where it would go'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $before = Get-GitTestRepoState -Repo $repo

    # Act - onto a file that exists, with -Force
    $run = Get-WhatIfOutput { Move-GitFile 'a.txt' 'b.txt' -Force -RepoPath $repo -WhatIf }

    # Assert
    Assert-Equal -Expected $before -Actual (Get-GitTestRepoState -Repo $repo) `
        -Message '-WhatIf with -Force overwrites nothing'
    Assert-Equal -Expected 0 -Actual $run.Output.Count -Message '-WhatIf with -Force returns nothing'
    Assert-Equal -Expected @(
        "What if: Performing the operation ""Move to $b, overwriting it if it exists"" on target ""$a""."
    ) -Actual $run.Messages -Message '-WhatIf with -Force says it would overwrite'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert
    Assert-Throws -ScriptBlock { Move-GitFile -Path 'a.txt' -Destination 'c.txt' -RepoPath $folder -WhatIf } `
        -MessageLike "*Renaming a.txt failed: '*' is not inside a git working tree*" `
        -Message '-WhatIf still refuses a folder that is no repository'
}
finally {
    Remove-GitTestRepo -Path $repo
    Remove-GitTestRepo -Path $folder
}

exit (Complete-TestRun)
