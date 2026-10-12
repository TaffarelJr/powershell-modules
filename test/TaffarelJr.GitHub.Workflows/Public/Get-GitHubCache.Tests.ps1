#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'createdAt,id,key,lastAccessedAt,ref,sizeInBytes,version'

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('[{"id":1,"key":"node-modules-abc","sizeInBytes":1024}]')
try {
    # Act
    $caches = Get-GitHubCache -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('cache', 'list', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message 'Caches are asked for as JSON with a fixed field set'
    Assert-That -Condition ($caches -is [array]) -Message 'A single cache is still returned as an array'
    Assert-Equal -Expected 1024 -Actual $caches[0].SizeInBytes -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every filter
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $caches = Get-GitHubCache -Key 'node-modules' -Ref 'refs/heads/main' -Sort size_in_bytes -Order asc -Limit 10
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('cache', 'list', '--json', $fields, '--key', 'node-modules', '--ref', 'refs/heads/main', '--sort', 'size_in_bytes', '--order', 'asc', '--limit', '10') -Actual $call.Arguments -Message 'Each filter becomes its gh flag'
    Assert-Equal -Expected 0 -Actual $caches.Count -Message 'No caches is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
