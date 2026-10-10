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
    Remove-GitHubReleaseAsset -Tag 'v1.0.0' -Name 'a.zip' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'delete-asset', 'v1.0.0', 'a.zip', '--yes', '--repo', 'o/r') -Actual $call.Arguments -Message 'The tag and asset are positional and the asset is deleted without prompting'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - asset names from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('a.zip', 'b.zip') | Remove-GitHubReleaseAsset -Tag 'v1'
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped asset is deleted in its own call'
    Assert-Equal -Expected @('release', 'delete-asset', 'v1', 'b.zip', '--yes') -Actual $calls[1].Arguments -Message 'The second piped asset is deleted too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
