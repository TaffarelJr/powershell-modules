#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every asset of one release into a folder
$fake = New-FakeGitHubCli
try {
    # Act
    Save-GitHubReleaseAsset -Tag 'v1.0.0' -Destination 'out' -Clobber -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'download', 'v1.0.0', '--dir', 'out', '--clobber', '--repo', 'o/r') -Actual $call.Arguments -Message 'The tag is positional and each option becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the latest release's matching assets and source archive
$fake = New-FakeGitHubCli
try {
    # Act
    Save-GitHubReleaseAsset -Pattern @('*.nupkg', '*.zip') -Archive zip -Output 'one.zip' -SkipExisting
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('release', 'download', '--pattern', '*.nupkg', '--pattern', '*.zip', '--archive', 'zip', '--output', 'one.zip', '--skip-existing') -Actual $call.Arguments -Message 'Without -Tag the latest release is used, one --pattern per pattern'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
