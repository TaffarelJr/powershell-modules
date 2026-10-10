#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a squash merge with a commit message
$fake = New-FakeGitHubCli
try {
    # Act
    Merge-GitHubPullRequest -PullRequest 12 -Strategy squash -Subject 'feat: thing' -Body 'Details' -DeleteBranch -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'merge', '12', '--squash', '--subject', 'feat: thing', '--body-file', '-', '--delete-branch', '--repo', 'o/r') -Actual $call.Arguments -Message 'The strategy becomes its gh flag and the body is read from standard input'
    Assert-Equal -Expected 'Details' -Actual $call.StdIn -Message 'The body itself is what gets piped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every remaining option
$fake = New-FakeGitHubCli
try {
    # Act
    Merge-GitHubPullRequest -Strategy rebase -AuthorEmail 'a@b.c' -Auto -DisableAuto -Admin -MatchHeadCommit 'abc123'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'merge', '--rebase', '--author-email', 'a@b.c', '--auto', '--disable-auto', '--admin', '--match-head-commit', 'abc123') -Actual $call.Arguments -Message 'Each option becomes its gh flag; without -PullRequest, the current branch''s is merged'
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'Nothing is piped without -Body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
