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
    # Act
    Remove-GitFile -Path 'a.txt' -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'a.txt')) -Message 'The file is removed from disk'
    Assert-Equal -Expected $true -Actual (Test-GitChange -Staged -RepoPath $repo) -Message 'The deletion is already staged'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a folder with a tracked file inside it
    git -C $repo commit --quiet -m 'remove a' 2>&1 | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repo 'sub') | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'sub/b.txt') -Value 'b' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add sub' 2>&1 | Out-Null

    # Act / Assert - a bare file delete refuses a folder
    Assert-Throws -ScriptBlock { Remove-GitFile -Path 'sub' -RepoPath $repo } -Message 'Deleting a folder without -Recurse throws'

    # Act - -Recurse deletes the whole folder
    Remove-GitFile -Path 'sub' -Recurse -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'sub')) -Message '-Recurse removes the folder'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two files, removed via the pipeline
    git -C $repo commit --quiet -m 'remove sub' 2>&1 | Out-Null
    Set-Content -LiteralPath (Join-Path $repo 'd.txt') -Value 'd' -NoNewline
    Set-Content -LiteralPath (Join-Path $repo 'e.txt') -Value 'e' -NoNewline
    git -C $repo add -A 2>&1 | Out-Null
    git -C $repo commit --quiet -m 'add d and e' 2>&1 | Out-Null

    # Act
    @('d.txt', 'e.txt') | Remove-GitFile -RepoPath $repo

    # Assert
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'd.txt')) -Message 'The first piped file is removed'
    Assert-Equal -Expected $false -Actual (Test-Path -LiteralPath (Join-Path $repo 'e.txt')) -Message 'The second piped file is removed'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
