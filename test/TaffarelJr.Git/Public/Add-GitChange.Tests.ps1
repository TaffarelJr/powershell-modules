#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$repo = New-GitTestRepo
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two new files
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'c.txt') -Value 'c' -NoNewline

    # Act - stage just one, by pathspec
    Add-GitChange -Path 'b.txt' -RepoPath $repo

    # Assert
    $status = Get-GitStatus -RepoPath $repo
    $staged = @($status | Where-Object { $_.Status[0] -ne ' ' -and $_.Status[0] -ne '?' })
    Assert-Equal -Expected 1 -Actual $staged.Count -Message 'Only the given path is staged'
    Assert-Equal -Expected 'b.txt' -Actual $staged[0].Path -Message 'The staged path is the one given'

    #───────────────────────────────────────────────────────────────────────────
    # Act - stage everything else with no -Path
    Add-GitChange -RepoPath $repo

    # Assert
    $allStatus = Get-GitStatus -RepoPath $repo
    $unstaged = @($allStatus | Where-Object { $_.Status[0] -eq ' ' -or $_.Status[0] -eq '?' })
    Assert-Equal -Expected 0 -Actual $unstaged.Count -Message 'Omitting -Path stages the entire working tree'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a third file, staged via the pipeline
    Set-Content -LiteralPath (Join-Path $repo 'd.txt') -Value 'd' -NoNewline

    # Act
    'd.txt' | Add-GitChange -RepoPath $repo

    # Assert
    $finalStatus = Get-GitStatus -RepoPath $repo
    $dEntry = @($finalStatus | Where-Object Path -eq 'd.txt')
    Assert-Equal -Expected 'A ' -Actual $dEntry[0].Status -Message 'A path piped in is staged'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
