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
    git -C $repo tag 'v1.0.0' 2>&1 | Out-Null

    # Act
    Remove-GitTag -Name 'v1.0.0' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual (Get-GitTag -RepoPath $repo).Count -Message 'The tag is deleted'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two more tags, removed via the pipeline
    git -C $repo tag 'v1.1.0' 2>&1 | Out-Null
    git -C $repo tag 'v1.2.0' 2>&1 | Out-Null

    # Act
    @('v1.1.0', 'v1.2.0') | Remove-GitTag -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual (Get-GitTag -RepoPath $repo).Count -Message 'Both piped tags are deleted'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
