#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'assignees,author,authorAssociation,body,closedAt,commentsCount,createdAt,id,isLocked,isPullRequest,labels,number,repository,state,title,updatedAt,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare query
$fake = New-FakeGitHubCli -Output @('[{"number":1,"title":"Bug"}]')
try {
    # Act
    $issues = Find-GitHubIssue -Query 'crash' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'issues', 'crash', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message 'The query is positional and the repository filter goes through --repo'
    Assert-Equal -Expected 'Bug' -Actual $issues[0].Title -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the switch and boolean filters, no query
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $issues = Find-GitHubIssue -NoLabel -NoMilestone -NoAssignee -NoProject -Archived $false -Locked -IncludePullRequests -State open -Limit 5
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'issues', '--json', $fields, '--state', 'open', '--no-label', '--no-milestone', '--no-assignee', '--no-project', '--archived', 'false', '--locked', '--include-prs', '--limit', '5') -Actual $call.Arguments -Message 'Each switch filter becomes its gh flag'
    Assert-Equal -Expected 0 -Actual $issues.Count -Message 'No results is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the remaining string/range filters
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubIssue -App 'dependabot' -Author 'me' -Assignee 'bob' -Mentions 'ann' -TeamMentions 'org/team' -Commenter 'cat' -Involves 'dog' -Label @('bug') -Milestone 'v1' -Project 'o/1' -Language PowerShell -Visibility @('public') -Comments '>5' -Interactions '>10' -Reactions '>2' -Created '>2026-01-01' -Updated '>2026-01-01' -Closed '>2026-01-01' -Match @('title', 'body') -SearchType hybrid -Sort created -Order asc | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'issues', '--json', $fields, '--app', 'dependabot', '--author', 'me', '--assignee', 'bob', '--mentions', 'ann', '--team-mentions', 'org/team', '--commenter', 'cat', '--involves', 'dog', '--label', 'bug', '--milestone', 'v1', '--project', 'o/1', '--language', 'PowerShell', '--visibility', 'public', '--comments', '>5', '--interactions', '>10', '--reactions', '>2', '--created', '>2026-01-01', '--updated', '>2026-01-01', '--closed', '>2026-01-01', '--match', 'title', '--match', 'body', '--search-type', 'hybrid', '--sort', 'created', '--order', 'asc') -Actual $call.Arguments -Message 'Every remaining filter becomes its gh flag'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
