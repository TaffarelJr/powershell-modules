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
# Arrange
$fake = New-FakeGitHubCli -Output @('{"assigned":[],"createdBy":[{"number":1,"title":"Roadmap"}],"mentioned":[]}')
try {
    # Act
    $status = Get-GitHubIssueStatus -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'status', '--json', $fields, '--repo', 'o/r') -Actual $call.Arguments -Message 'Status is asked for as JSON with a fixed field set'
    Assert-Equal -Expected 0 -Actual $status.Assigned.Count -Message 'An empty group is an empty array'
    Assert-Equal -Expected 1 -Actual $status.CreatedBy.Count -Message "The user's own issues are an array"
    Assert-Equal -Expected 'Roadmap' -Actual $status.CreatedBy[0].Title -Message 'Each issue in a group is parsed and re-cased'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
