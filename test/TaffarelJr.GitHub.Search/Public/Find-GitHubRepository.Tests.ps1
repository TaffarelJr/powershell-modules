#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'createdAt,defaultBranch,description,forksCount,fullName,hasDownloads,hasIssues,hasPages,hasProjects,hasWiki,homepage,id,isArchived,isDisabled,isFork,isPrivate,language,license,name,openIssuesCount,owner,pushedAt,size,stargazersCount,updatedAt,url,visibility,watchersCount'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare query
$fake = New-FakeGitHubCli -Output @('[{"fullName":"o/r","stargazersCount":10}]')
try {
    # Act
    $repos = Find-GitHubRepository -Query 'powershell module'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'repos', 'powershell module', '--json', $fields) -Actual $call.Arguments -Message 'The query is positional'
    Assert-That -Condition ($repos -is [array]) -Message 'A single result is still returned as an array'
    Assert-Equal -Expected 'o/r' -Actual $repos[0].FullName -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every filter, no query
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $repos = Find-GitHubRepository -Owner @('o1', 'o2') -Language PowerShell -Topic @('ci') -License @('mit') -Visibility @('public') -Archived $false -IncludeForks true -Stars '>100' -Forks '>10' -Size '<500' -GoodFirstIssues '>0' -HelpWantedIssues '>0' -NumberTopics '>1' -Created '>2026-01-01' -Updated '>2026-01-01' -Match @('name', 'readme') -Sort stars -Order desc -Limit 5
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'repos', '--json', $fields, '--owner', 'o1', '--owner', 'o2', '--language', 'PowerShell', '--topic', 'ci', '--license', 'mit', '--visibility', 'public', '--archived', 'false', '--include-forks', 'true', '--stars', '>100', '--forks', '>10', '--size', '<500', '--good-first-issues', '>0', '--help-wanted-issues', '>0', '--number-topics', '>1', '--created', '>2026-01-01', '--updated', '>2026-01-01', '--match', 'name', '--match', 'readme', '--sort', 'stars', '--order', 'desc', '--limit', '5') -Actual $call.Arguments -Message 'Every filter becomes its gh flag'
    Assert-Equal -Expected 0 -Actual $repos.Count -Message 'No results is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
