#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - several files in one upload
$fake = New-FakeGitHubCli
try {
    # Act
    Add-GitHubReleaseAsset -Tag 'v1.0.0' -Path @('a.zip', 'b.nupkg#Package') -Clobber -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'upload', 'v1.0.0', 'a.zip', 'b.nupkg#Package', '--clobber', '--repo', 'o/r') -Actual $call.Arguments -Message 'The files follow the tag and -Clobber becomes --clobber'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - files from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('a.zip', 'b.zip') | Add-GitHubReleaseAsset -Tag 'v1'
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped file is uploaded in its own call'
    Assert-Equal -Expected @('release', 'upload', 'v1', 'b.zip') -Actual $calls[1].Arguments -Message 'The second piped file is uploaded too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
