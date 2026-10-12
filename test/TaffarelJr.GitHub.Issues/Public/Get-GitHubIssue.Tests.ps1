#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'assignees,author,blockedBy,blocking,body,closed,closedAt,closedByPullRequestsReferences,comments,createdAt,id,isPinned,issueType,labels,milestone,number,parent,projectCards,projectItems,reactionGroups,state,stateReason,subIssues,subIssuesSummary,title,updatedAt,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one issue by number
$fake = New-FakeGitHubCli -Output @('{"number":12,"title":"Bug","isPinned":false}')
try {
    # Act
    $issue = Get-GitHubIssue -Issue 12 -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'view', '12', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message 'The issue is positional and the repository goes through --repo'
    Assert-Equal -Expected 'Bug' -Actual $issue.Title -Message 'The issue comes back as one object with PascalCase fields'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an issue piped in by its Number property, as a listing returns it
$fake = New-FakeGitHubCli -Output @('{"number":7}')
try {
    # Act
    $issue = [PSCustomObject]@{ Number = 7 } | Get-GitHubIssue
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'view', '7', '--json', $fields) -Actual $call.Arguments -Message 'The Number property binds from the pipeline as -Issue'
    Assert-Equal -Expected 7 -Actual $issue.Number -Message 'The piped issue is described'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing with every filter
$fake = New-FakeGitHubCli -Output @('[{"number":1},{"number":2}]')
try {
    # Act
    $issues = Get-GitHubIssue -List -State all -Author '@me' -App 'dependabot' -Assignee 'me' -Mention 'bob' -Label @('bug', 'p1') -Milestone 'v1' -Type 'Bug' -Search 'status:open' -Limit 5 -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'list', '--json', $fields, '--state', 'all', '--author', '@me', '--app', 'dependabot', '--assignee', 'me', '--mention', 'bob', '--label', 'bug', '--label', 'p1', '--milestone', 'v1', '--type', 'Bug', '--search', 'status:open', '--limit', '5', '--repo', 'o/r') -Actual $call.Arguments -Message 'Each filter becomes its gh flag, one --label per label'
    Assert-Equal -Expected 2 -Actual $issues.Count -Message 'Every listed issue is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a single listed issue, and no issues at all
$fake = New-FakeGitHubCli -Output @('[{"number":1}]')
try {
    # Act
    $issues = Get-GitHubIssue -List

    # Assert
    Assert-That -Condition ($issues -is [array]) -Message 'A single listed issue is still returned as an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $issues = Get-GitHubIssue -List

    # Assert
    Assert-Equal -Expected 0 -Actual $issues.Count -Message 'No issues is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
