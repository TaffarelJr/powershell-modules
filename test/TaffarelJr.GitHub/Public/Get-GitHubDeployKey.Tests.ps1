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
$fake = New-FakeGitHubCli -Output @('[{"id":1,"title":"deploy","readOnly":true}]')
try {
    # Act
    $keys = Get-GitHubDeployKey -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('repo', 'deploy-key', 'list', '--json', 'createdAt,id,key,readOnly,title', '--repo', 'o/r') -Actual $call.Arguments -Message 'The keys are asked for as JSON with a fixed field set'
    Assert-That -Condition ($keys -is [array]) -Message 'A single key is still returned as an array'
    Assert-Equal -Expected $true -Actual $keys[0].ReadOnly -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no keys
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $keys = Get-GitHubDeployKey

    # Assert
    Assert-Equal -Expected 0 -Actual $keys.Count -Message 'No keys is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
