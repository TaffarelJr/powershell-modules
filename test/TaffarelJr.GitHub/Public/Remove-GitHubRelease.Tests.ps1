#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubRelease -Tag 'v1.0.0' -CleanupTag -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'delete', 'v1.0.0', '--yes', '--cleanup-tag', '--repo', 'o/r') -Actual $call.Arguments -Message 'The release is deleted without prompting, tag included'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - releases piped in as Get-GitHubRelease -List returns them
$fake = New-FakeGitHubCli
try {
    # Act
    @([PSCustomObject]@{ TagName = 'v1' }, [PSCustomObject]@{ TagName = 'v2' }) | Remove-GitHubRelease
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped release is deleted in its own call'
    Assert-Equal -Expected @('release', 'delete', 'v2', '--yes') -Actual $calls[1].Arguments -Message 'The TagName property binds from the pipeline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
