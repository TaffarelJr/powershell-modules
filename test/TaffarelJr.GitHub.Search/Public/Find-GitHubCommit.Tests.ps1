#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'author,commit,committer,id,parents,repository,sha,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare query
$fake = New-FakeGitHubCli -Output @('[{"sha":"abc123"}]')
try {
    # Act
    $commits = Find-GitHubCommit -Query 'fix' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'commits', 'fix', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message 'The query is positional and the repository filter goes through --repo'
    Assert-Equal -Expected 'abc123' -Actual $commits[0].Sha -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every other filter, no query
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $commits = Find-GitHubCommit -Owner @('o1') -Author 'me' -AuthorName 'Me' -AuthorEmail 'm@e.com' -AuthorDate '>2026-01-01' -Committer 'me' -CommitterName 'Me' -CommitterEmail 'm@e.com' -CommitterDate '>2026-01-01' -Hash 'abc' -Parent 'def' -Tree 'ghi' -Merge -Visibility @('public') -Sort author-date -Order asc -Limit 5
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'commits', '--json', $fields, '--owner', 'o1', '--author', 'me', '--author-name', 'Me', '--author-email', 'm@e.com', '--author-date', '>2026-01-01', '--committer', 'me', '--committer-name', 'Me', '--committer-email', 'm@e.com', '--committer-date', '>2026-01-01', '--hash', 'abc', '--parent', 'def', '--tree', 'ghi', '--merge', '--visibility', 'public', '--sort', 'author-date', '--order', 'asc', '--limit', '5') -Actual $call.Arguments -Message 'Every filter becomes its gh flag'
    Assert-Equal -Expected 0 -Actual $commits.Count -Message 'No results is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
