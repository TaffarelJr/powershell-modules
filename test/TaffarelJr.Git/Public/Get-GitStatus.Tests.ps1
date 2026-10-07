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
    # Arrange / Act / Assert - a clean working tree
    Assert-Equal -Expected 0 -Actual (Get-GitStatus -RepoPath $repo).Count -Message 'A clean working tree returns nothing'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - an untracked file and a modified one
    Set-Content -LiteralPath (Join-Path $repo 'a.txt') -Value 'changed' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'new' -NoNewline

    # Act
    $unsorted = Get-GitStatus -RepoPath $repo
    $status = @($unsorted | Sort-Object Path)

    # Assert
    Assert-Equal -Expected 2 -Actual $status.Count -Message 'Both the modified and the untracked file are reported'
    Assert-Equal -Expected 'a.txt' -Actual $status[0].Path -Message 'The modified file is reported'
    Assert-Equal -Expected ' M' -Actual $status[0].Status -Message 'Its status code marks it modified, unstaged'
    Assert-Equal -Expected 'b.txt' -Actual $status[1].Path -Message 'The untracked file is reported'
    Assert-Equal -Expected '??' -Actual $status[1].Status -Message 'Its status code marks it untracked'
    Assert-Equal -Expected $null -Actual $status[0].OldPath -Message 'OldPath is $null for anything that is not a rename'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - stage, then rename the tracked file
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add b' 2>&1 | Out-Null
    git -C $repo mv b.txt c.txt 2>&1 | Out-Null

    # Act
    $renamed = @(Get-GitStatus -RepoPath $repo)

    # Assert
    Assert-Equal -Expected 1 -Actual $renamed.Count -Message 'A rename is reported as a single entry'
    Assert-Equal -Expected 'c.txt' -Actual $renamed[0].Path -Message 'Path is the new name'
    Assert-Equal -Expected 'b.txt' -Actual $renamed[0].OldPath -Message 'OldPath is the original name'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
