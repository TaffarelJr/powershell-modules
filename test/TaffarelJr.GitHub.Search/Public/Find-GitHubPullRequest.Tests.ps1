#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'assignees,author,authorAssociation,body,closedAt,commentsCount,createdAt,id,isDraft,isLocked,isPullRequest,labels,number,repository,state,title,updatedAt,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare query
$fake = New-FakeGitHubCli -Output @('[{"number":1,"title":"Fix"}]')
try {
    # Act
    $prs = Find-GitHubPullRequest -Query 'fix' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'prs', 'fix', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message 'The query is positional and the repository filter goes through --repo'
    Assert-Equal -Expected 'Fix' -Actual $prs[0].Title -Message 'Field names are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the pr-specific filters, no query
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $prs = Find-GitHubPullRequest -Base 'main' -Head 'fix-1' -Draft -Merged -MergedAt '>2026-01-01' -Checks success -Review approved -ReviewRequested 'bob' -ReviewedBy 'ann' -Limit 5
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'prs', '--json', $fields, '--base', 'main', '--head', 'fix-1', '--draft', '--merged', '--merged-at', '>2026-01-01', '--checks', 'success', '--review', 'approved', '--review-requested', 'bob', '--reviewed-by', 'ann', '--limit', '5') -Actual $call.Arguments -Message 'Each pr-specific filter becomes its gh flag'
    Assert-Equal -Expected 0 -Actual $prs.Count -Message 'No results is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the filters shared with issue search
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Find-GitHubPullRequest -NoLabel -NoMilestone -NoAssignee -NoProject -Archived $true -Locked -State closed -Label @('bug') -Milestone 'v1' -Language PowerShell -Visibility @('public') -Comments '>1' -Interactions '>1' -Created '>2026-01-01' -Updated '>2026-01-01' -Closed '>2026-01-01' -Match @('title') -Sort updated -Order desc | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('search', 'prs', '--json', $fields, '--state', 'closed', '--label', 'bug', '--no-label', '--milestone', 'v1', '--no-milestone', '--no-assignee', '--no-project', '--language', 'PowerShell', '--visibility', 'public', '--archived', 'true', '--locked', '--comments', '>1', '--interactions', '>1', '--created', '>2026-01-01', '--updated', '>2026-01-01', '--closed', '>2026-01-01', '--match', 'title', '--sort', 'updated', '--order', 'desc') -Actual $call.Arguments -Message 'Each shared filter becomes its gh flag, in declared order'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
