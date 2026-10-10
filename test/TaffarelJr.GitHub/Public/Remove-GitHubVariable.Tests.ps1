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
    Remove-GitHubVariable -Name 'OLD' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'delete', 'OLD', '--repo', 'o/r') -Actual $call.Arguments -Message 'The name and repository are passed to gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - scoped to an environment and organization
$fake = New-FakeGitHubCli
try {
    # Act
    Remove-GitHubVariable -Name 'OLD' -Environment 'prod' -Organization 'org'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'delete', 'OLD', '--env', 'prod', '--org', 'org') -Actual $call.Arguments -Message 'Each scope option becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names from the pipeline
$fake = New-FakeGitHubCli
try {
    # Act
    @('A', 'B') | Remove-GitHubVariable
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped name is deleted in its own call'
    Assert-Equal -Expected @('variable', 'delete', 'B') -Actual $calls[1].Arguments -Message 'The second piped name is deleted too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
