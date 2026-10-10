#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$fields = 'additions,assignees,author,autoMergeRequest,baseRefName,body,changedFiles,closedAt,createdAt,deletions,headRefName,headRefOid,headRepository,headRepositoryOwner,isCrossRepository,isDraft,labels,mergeStateStatus,mergeable,mergedAt,mergedBy,milestone,number,reviewDecision,reviewRequests,state,statusCheckRollup,title,updatedAt,url'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one pull request by number
$fake = New-FakeGitHubCli -Output @('{"number":12,"title":"Fix","headRefName":"fix","author":{"login":"me"}}')
try {
    # Act
    $pullRequest = Get-GitHubPullRequest -PullRequest 12 -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'view', '12', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message 'The pull request is positional and the repository goes through --repo'
    Assert-Equal -Expected 'fix' -Actual $pullRequest.HeadRefName -Message 'The pull request comes back as one object with PascalCase fields'
    Assert-Equal -Expected 'me' -Actual $pullRequest.Author.Login -Message 'Nested objects are re-cased too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the current branch's pull request
$fake = New-FakeGitHubCli -Output @('{"number":1}')
try {
    # Act
    Get-GitHubPullRequest | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'view', '--json', $fields) -Actual $call.Arguments -Message 'Without -PullRequest, gh uses the current branch''s'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing with every filter
$fake = New-FakeGitHubCli -Output @('[{"number":1},{"number":2}]')
try {
    # Act
    $pullRequests = Get-GitHubPullRequest -List -State all -Base 'main' -Head 'template-sync' -Author '@me' -App 'dependabot' -Assignee 'me' -Label @('bug', 'needs fix') -Search 'status:success' -Draft:$false -Limit 5 -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'list', '--json', $fields, '--state', 'all', '--base', 'main', '--head', 'template-sync', '--author', '@me', '--app', 'dependabot', '--assignee', 'me', '--label', 'bug', '--label', 'needs fix', '--search', 'status:success', '--draft=false', '--limit', '5', '--repo', 'o/r') -Actual $call.Arguments -Message 'Each filter becomes its gh flag, one --label per label, -Draft as a three-state toggle'
    Assert-Equal -Expected 2 -Actual $pullRequests.Count -Message 'Every listed pull request is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing drafts only, one result
$fake = New-FakeGitHubCli -Output @('[{"number":3,"isDraft":true}]')
try {
    # Act
    $pullRequests = Get-GitHubPullRequest -List -Draft
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'list', '--json', $fields, '--draft=true') -Actual $call.Arguments -Message '-Draft alone lists drafts only'
    Assert-That -Condition ($pullRequests -is [array]) -Message 'A single listed pull request is still returned as an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no open pull requests
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    $pullRequests = Get-GitHubPullRequest -List

    # Assert
    Assert-Equal -Expected 0 -Actual $pullRequests.Count -Message 'No pull requests is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
