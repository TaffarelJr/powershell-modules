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
    Remove-GitHubRepository -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'delete', 'o/r', '--yes') -Actual $call.Arguments -Message 'The named repository is deleted without prompting'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - repositories from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('o/a', 'o/b') | Remove-GitHubRepository
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped repository is deleted in its own call'
    Assert-Equal -Expected @('repo', 'delete', 'o/b', '--yes') -Actual $calls[1].Arguments -Message 'The second piped repository is deleted too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
