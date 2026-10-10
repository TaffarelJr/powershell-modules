#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the endpoint answers
$fake = New-FakeGitHubCli
try {
    # Act
    $exists = Test-GitHubApi -Endpoint 'repos/o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('api', 'repos/o/r', '--silent') -Actual $call.Arguments -Message 'The probe asks gh to discard the body'
    Assert-Equal -Expected $true -Actual $exists -Message 'A successful request reports $true'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the endpoint does not answer
$fake = New-FakeGitHubCli -Output @('{"message":"Not Found"}') -ExitCode 1
try {
    # Act
    $exists = Test-GitHubApi -Endpoint 'repos/o/missing' -Hostname 'ghe.example'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected $false -Actual $exists -Message 'A failed request reports $false instead of throwing'
    Assert-Equal -Expected @('api', 'repos/o/missing', '--silent', '--hostname', 'ghe.example') -Actual $call.Arguments -Message '-Hostname is passed through'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
