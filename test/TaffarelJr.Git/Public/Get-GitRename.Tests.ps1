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
    # Arrange
    $before = (git -C $repo rev-parse HEAD).Trim()
    git -C $repo mv a.txt renamed.txt 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'rename a' 2>&1 | Out-Null
    $after = (git -C $repo rev-parse HEAD).Trim()

    # Act
    $renames = Get-GitRename -FromRef $before -ToRef $after -RepoPath $repo

    # Assert
    Assert-Equal -Expected 1 -Actual $renames.Count -Message 'The rename is detected'
    Assert-Equal -Expected 'a.txt' -Actual $renames[0].OldPath -Message 'OldPath is the original name'
    Assert-Equal -Expected 'renamed.txt' -Actual $renames[0].NewPath -Message 'NewPath is the new name'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a commit with no renames at all
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add b' 2>&1 | Out-Null

    # Act / Assert
    $none = Get-GitRename -FromRef $after -ToRef 'HEAD' -RepoPath $repo
    Assert-Equal -Expected 0 -Actual $none.Count -Message 'A plain add reports no renames'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
