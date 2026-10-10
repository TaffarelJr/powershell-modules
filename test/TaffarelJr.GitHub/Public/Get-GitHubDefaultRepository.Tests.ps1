#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a default is set
$fake = New-FakeGitHubCli -Output @('o/r')
try {
    # Act
    $default = Get-GitHubDefaultRepository
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'set-default', '--view') -Actual $call.Arguments -Message 'gh is asked to show the default'
    Assert-Equal -Expected 'o/r' -Actual $default -Message 'The default repository is returned as a string'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - none is set, which gh reports as a failure
$fake = New-FakeGitHubCli -Output @('no default repository has been set') -ExitCode 1
try {
    # Act
    $default = Get-GitHubDefaultRepository

    # Assert
    Assert-That -Condition ($null -eq $default) -Message 'No default is $null, not an error'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
