#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Git/TaffarelJr.Git.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitTestHelper.ps1')

$origin = New-GitTestRepo
$clone = Join-Path ([System.IO.Path]::GetTempPath()) "git-test-$([Guid]::NewGuid())"
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a clone, which records origin's HEAD symref locally
    git clone --quiet $origin $clone 2>&1 | Out-Null

    # Act / Assert
    Assert-Equal -Expected 'main' -Actual (Get-GitDefaultBranch -RepoPath $clone) `
        -Message "Reads the remote's default branch from the local HEAD symref"

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert - a remote that does not exist
    Assert-Equal -Expected $null -Actual (Get-GitDefaultBranch -Name 'nope' -RepoPath $clone) `
        -Message 'A missing remote returns $null'
}
finally {
    Remove-GitTestRepo -Path $origin
    Remove-GitTestRepo -Path $clone
}

exit (Complete-TestRun)
