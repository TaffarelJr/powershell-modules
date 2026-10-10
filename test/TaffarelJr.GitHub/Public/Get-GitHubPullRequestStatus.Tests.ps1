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
# Arrange
$fake = New-FakeGitHubCli -Output @('{"currentBranch":{"number":5},"createdBy":[{"number":5}],"needsReview":[]}')
try {
    # Act
    $status = Get-GitHubPullRequestStatus -ConflictStatus -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'status', '--json', $fields, '--conflict-status', '--repo', 'o/r') -Actual $call.Arguments -Message 'Status is asked for as JSON, with the conflict flag and repository'
    Assert-Equal -Expected 5 -Actual $status.CurrentBranch.Number -Message 'The current branch''s pull request is one object'
    Assert-Equal -Expected 1 -Actual $status.CreatedBy.Count -Message 'The user''s own pull requests are an array'
    Assert-Equal -Expected 0 -Actual $status.NeedsReview.Count -Message 'An empty group is an empty array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no pull request on the current branch
$fake = New-FakeGitHubCli -Output @('{"currentBranch":null,"createdBy":[],"needsReview":[]}')
try {
    # Act
    $status = Get-GitHubPullRequestStatus
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'status', '--json', $fields) -Actual $call.Arguments -Message 'Without options, only the JSON request is made'
    Assert-That -Condition ($null -eq $status.CurrentBranch) -Message 'No pull request on the current branch is $null'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
