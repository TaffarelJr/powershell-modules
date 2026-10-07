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
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    git -C $repo tag 'v1.0.0' 2>&1 | Out-Null

    Remove-GitTag -Name 'v1.0.0' -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitTag -RepoPath $repo).Count -Message 'The tag is deleted'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two more tags, removed via the pipeline
    git -C $repo tag 'v1.1.0' 2>&1 | Out-Null
    git -C $repo tag 'v1.2.0' 2>&1 | Out-Null

    # Act
    @('v1.1.0', 'v1.2.0') | Remove-GitTag -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitTag -RepoPath $repo).Count -Message 'Both piped tags are deleted'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - two tags, removed by piping Get-GitTag straight in
    git -C $repo tag 'v2.0.0' 2>&1 | Out-Null
    git -C $repo tag 'v2.1.0' 2>&1 | Out-Null

    # Act
    Get-GitTag -RepoPath $repo | Remove-GitTag -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitTag -RepoPath $repo).Count `
        -Message 'Get-GitTag pipes straight into Remove-GitTag'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - a tag, described by an object with a Name property
    git -C $repo tag 'v3.0.0' 2>&1 | Out-Null
    $described = [PSCustomObject]@{
        Name    = 'v3.0.0'
        Version = '3.0.0'
    }

    # Act
    $described | Remove-GitTag -RepoPath $repo

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-GitTag -RepoPath $repo).Count `
        -Message 'An object is bound by its Name property'
}
finally {
    Remove-GitTestRepo -Path $repo
}

exit (Complete-TestRun)
