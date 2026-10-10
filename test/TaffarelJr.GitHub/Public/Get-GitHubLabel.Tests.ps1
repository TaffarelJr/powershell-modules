#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$fields = 'color,createdAt,description,id,isDefault,name,updatedAt,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('[{"name":"bug","color":"d73a4a","isDefault":true}]')
try {
    # Act
    $labels = Get-GitHubLabel -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('label', 'list', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message 'Labels are asked for as JSON with a fixed field set'
    Assert-That -Condition ($labels -is [array]) -Message 'A single label is still returned as an array'
    Assert-Equal -Expected $true -Actual $labels[0].IsDefault -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every option
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $labels = Get-GitHubLabel -Search 'bug' -Sort name -Order desc -Limit 100
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('label', 'list', '--json', $fields, '--search', 'bug', '--sort', 'name', '--order', 'desc', '--limit', '100') -Actual $call.Arguments -Message 'Each option becomes its gh flag'
    Assert-Equal -Expected 0 -Actual $labels.Count -Message 'No labels is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
