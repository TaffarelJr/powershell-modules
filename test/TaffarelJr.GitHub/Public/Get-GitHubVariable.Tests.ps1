#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$fields = 'createdAt,name,numSelectedRepos,selectedReposURL,updatedAt,value,visibility'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one variable by name
$fake = New-FakeGitHubCli -Output @('{"name":"CI_LANGUAGES","value":"dotnet","visibility":"private"}')
try {
    # Act
    $variable = Get-GitHubVariable -Name 'CI_LANGUAGES' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'get', 'CI_LANGUAGES', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message '-Name asks gh for that one variable'
    Assert-Equal -Expected 'dotnet' -Actual $variable.Value -Message 'The variable comes back as one object with PascalCase fields'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every variable, scoped to an environment and organization
$fake = New-FakeGitHubCli -Output @('[{"name":"A","value":"1"}]')
try {
    # Act
    $variables = Get-GitHubVariable -Environment 'prod' -Organization 'org'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('variable', 'list', '--json', $fields, '--env', 'prod', '--org', 'org') -Actual $call.Arguments -Message 'Without -Name, every variable is listed with the scope flags'
    Assert-That -Condition ($variables -is [array]) -Message 'A single listed variable is still returned as an array'
    Assert-Equal -Expected 'A' -Actual $variables[0].Name -Message 'The listed variable is parsed'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no variables
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $variables = Get-GitHubVariable

    # Assert
    Assert-Equal -Expected 0 -Actual $variables.Count -Message 'No variables is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
