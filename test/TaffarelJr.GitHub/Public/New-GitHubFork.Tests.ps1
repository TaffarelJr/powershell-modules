#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a fork of a named repository, nothing local
$fake = New-FakeGitHubCli
try {
    # Act
    New-GitHubFork -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'fork', 'o/r', '--clone=false', '--remote=false') -Actual $call.Arguments -Message 'Cloning and adding a remote are both explicitly declined, so gh has nothing to ask'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every option
$fake = New-FakeGitHubCli
try {
    # Act
    New-GitHubFork -Organization 'org' -ForkName 'mine' -DefaultBranchOnly -Clone -Remote -RemoteName 'fork'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'fork', '--clone=true', '--remote=true', '--org', 'org', '--fork-name', 'mine', '--default-branch-only', '--remote-name', 'fork') -Actual $call.Arguments -Message 'Each option becomes its gh flag; without -Repository, the current one is forked'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
