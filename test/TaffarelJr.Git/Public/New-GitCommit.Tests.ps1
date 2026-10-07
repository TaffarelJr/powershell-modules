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
    Set-Content -LiteralPath (Join-Path $repo 'b.txt') -Value 'b' -NoNewline
    Add-GitChange -RepoPath $repo

    # Act
    New-GitCommit -Message 'add b' -RepoPath $repo

    # Assert
    $commit = Get-GitCommit -RepoPath $repo
    Assert-Equal -Expected 'add b' -Actual $commit.Subject -Message 'Commits staged changes with the given message'
    Assert-Equal -Expected $false -Actual (Test-GitChange -Staged -RepoPath $repo) -Message 'Nothing is left staged afterward'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - nothing staged throws without -AllowEmpty
    Assert-Throws -ScriptBlock { New-GitCommit -Message 'empty' -RepoPath $repo } `
        -Message 'Committing with nothing staged throws without -AllowEmpty'

    # Act - -AllowEmpty permits it
    New-GitCommit -Message 'empty marker' -AllowEmpty -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'empty marker' -Actual (Get-GitCommit -RepoPath $repo).Subject -Message '-AllowEmpty commits with nothing staged'

    #───────────────────────────────────────────────────────────────────────────
    # Act - -Amend changes the previous commit's message
    New-GitCommit -Message 'amended message' -Amend -AllowEmpty -RepoPath $repo

    # Assert
    $log = Get-GitLog -Count 2 -RepoPath $repo
    Assert-Equal -Expected 'amended message' -Actual $log[0].Subject -Message '-Amend replaces the previous commit instead of adding a new one'
    Assert-Equal -Expected 'add b' -Actual $log[1].Subject -Message 'The commit before that is untouched'

    #───────────────────────────────────────────────────────────────────────────
    # Act / Assert - -Message is required unless -Amend and -NoEdit are both set
    Assert-Throws -ScriptBlock { New-GitCommit -AllowEmpty -RepoPath $repo } `
        -Message '-Message is required outside of -Amend -NoEdit'

    # Act - -Amend -NoEdit keeps the existing message
    New-GitCommit -Amend -NoEdit -AllowEmpty -RepoPath $repo

    # Assert
    Assert-Equal -Expected 'amended message' -Actual (Get-GitCommit -RepoPath $repo).Subject `
        -Message '-Amend -NoEdit keeps the existing message unchanged'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
