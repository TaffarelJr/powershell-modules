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
$fake = New-FakeGitHubCli -Output @('[{"id":1,"name":"CI","path":".github/workflows/ci.yml","state":"active"}]')
try {
    # Act
    $workflows = Get-GitHubWorkflow -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'list', '--json', 'id,name,path,state', '--repo', 'o/r') -Actual $call.Arguments -Message 'Workflows are asked for as JSON with a fixed field set'
    Assert-That -Condition ($workflows -is [array]) -Message 'A single workflow is still returned as an array'
    Assert-Equal -Expected '.github/workflows/ci.yml' -Actual $workflows[0].Path -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - disabled ones too, capped
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $workflows = Get-GitHubWorkflow -All -Limit 10
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'list', '--json', 'id,name,path,state', '--all', '--limit', '10') -Actual $call.Arguments -Message '-All and -Limit become their gh flags'
    Assert-Equal -Expected 0 -Actual $workflows.Count -Message 'No workflows is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
