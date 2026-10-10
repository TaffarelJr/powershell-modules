#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - two accounts, already flattened by the jq gh is asked to apply
$fake = New-FakeGitHubCli -Output @('[{"host":"github.com","login":"me","active":true,"state":"success"},{"host":"github.com","login":"work","active":false,"state":"success"}]')
try {
    # Act
    $accounts = Get-GitHubAuthStatus
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'status', '--json', 'hosts', '--jq', '.hosts | add // []') -Actual $call.Arguments -Message 'gh is asked for JSON, flattened across hosts'
    Assert-Equal -Expected 2 -Actual $accounts.Count -Message 'Every account is returned'
    Assert-Equal -Expected 'me' -Actual $accounts[0].Login -Message 'Field names are PascalCase'
    Assert-Equal -Expected $true -Actual $accounts[0].Active -Message 'The active flag is carried over'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a narrowed query
$fake = New-FakeGitHubCli -Output @('[{"host":"ghe.example","login":"me","active":true}]')
try {
    # Act
    $accounts = Get-GitHubAuthStatus -Hostname 'ghe.example' -Active -ShowToken
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('auth', 'status', '--json', 'hosts', '--jq', '.hosts | add // []', '--hostname', 'ghe.example', '--active', '--show-token') -Actual $call.Arguments -Message 'Each option becomes its gh flag'
    Assert-That -Condition ($accounts -is [array]) -Message 'A single account is still returned as an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no accounts at all
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $accounts = Get-GitHubAuthStatus

    # Assert
    Assert-That -Condition ($accounts -is [array]) -Message 'No accounts is an empty array, not $null'
    Assert-Equal -Expected 0 -Actual $accounts.Count -Message 'No accounts means zero results'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
