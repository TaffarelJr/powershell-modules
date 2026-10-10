#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a plain approval
$fake = New-FakeGitHubCli
try {
    # Act
    Submit-GitHubPullRequestReview -PullRequest 12 -Decision Approve -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'review', '12', '--approve', '--repo', 'o/r') -Actual $call.Arguments -Message 'Approve becomes --approve, with no body'
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'Nothing is piped without -Body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a change request with a body
$fake = New-FakeGitHubCli
try {
    # Act
    Submit-GitHubPullRequestReview -Decision RequestChanges -Body 'Needs tests'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'review', '--request-changes', '--body-file', '-') -Actual $call.Arguments -Message 'RequestChanges becomes --request-changes and the body is read from standard input'
    Assert-Equal -Expected 'Needs tests' -Actual $call.StdIn -Message 'The body itself is what gets piped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a comment
$fake = New-FakeGitHubCli
try {
    # Act
    Submit-GitHubPullRequestReview -Decision Comment -Body 'Looks interesting'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'review', '--comment', '--body-file', '-') -Actual $call.Arguments -Message 'Comment becomes --comment'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
