#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'path,repository,sha,textMatches,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('[{"path":"src/x.ps1","sha":"abc"}]')
try {
    # Act
    $results = Find-GitHubCode -Query 'Invoke-GitHubCommand' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'code', 'Invoke-GitHubCommand', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message 'The query is positional and the repository filter goes through --repo'
    Assert-Equal -Expected 'src/x.ps1' -Actual $results[0].Path -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every other filter
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $results = Find-GitHubCode -Query 'TODO' -Owner @('o1') -Language PowerShell -Filename 'Invoke-*.ps1' -Extension 'ps1' -Match @('file', 'path') -Size '<10' -Limit 5
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'code', 'TODO', '--json', $fields, '--owner', 'o1', '--language', 'PowerShell', '--filename', 'Invoke-*.ps1', '--extension', 'ps1', '--match', 'file', '--match', 'path', '--size', '<10', '--limit', '5') -Actual $call.Arguments -Message 'Each option becomes its gh flag'
    Assert-Equal -Expected 0 -Actual $results.Count -Message 'No results is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
