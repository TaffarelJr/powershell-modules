#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') `
    -Force `
    -PassThru
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = & $module { Get-GitHubPullRequestField }

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli -Output @('{"currentBranch":{"number":5},"createdBy":[{"number":5}],"needsReview":[]}')
try {
    # Act
    $status = Get-GitHubPullRequestStatus -ConflictStatus -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'status', '--json', $fields, '--conflict-status', '--repo', 'o/r') `
        -Actual $call.Arguments `
        -Message 'Status is asked for as JSON, with the conflict flag and repository'
    Assert-Equal -Expected 5 -Actual $status.CurrentBranch.Number `
        -Message 'The current branch''s pull request is one object'
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
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'status', '--json', $fields) -Actual $call.Arguments `
        -Message 'Without options, only the JSON request is made'
    Assert-Equal -Expected $null -Actual $status.CurrentBranch -Message 'No pull request on the current branch is $null'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - only some fields
$fake = New-FakeGitHubCli -Output @('{"currentBranch":null,"createdBy":[],"needsReview":[]}')
try {
    # Act
    Get-GitHubPullRequestStatus -Property 'Title', 'ReviewDecision' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'status', '--json', 'title,reviewDecision,url,number') -Actual $call.Arguments `
        -Message '-Property asks for those fields, plus url and number'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh fails
$fake = New-FakeGitHubCli -ErrorOutput @('not a git repository') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestStatus
    } -MessageLike 'Reading pull request status failed*not a git repository*' `
        -Message 'A failure throws with the message from gh'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository given by position
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestStatus 'o/r'
    } -MessageLike '*positional parameter cannot be found*' `
        -Message 'No parameter is taken by position, so o/r is not asked for as a field'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
