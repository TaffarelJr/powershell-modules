#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a new comment
$fake = New-FakeGitHubCli
try {
    # Act
    Add-GitHubPullRequestComment -PullRequest 12 -Body "Hi`nthere" -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'comment', '12', '--body-file', '-', '--repo', 'o/r') -Actual $call.Arguments -Message 'The body is read from standard input'
    Assert-Equal -Expected "Hi`nthere" -Actual $call.StdIn -Message 'The body itself is what gets piped, newlines included'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - editing the last comment, creating one if there is none
$fake = New-FakeGitHubCli
try {
    # Act
    Add-GitHubPullRequestComment -Body 'Updated' -EditLast -CreateIfNone
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'comment', '--body-file', '-', '--edit-last', '--create-if-none') -Actual $call.Arguments -Message '-EditLast and -CreateIfNone become their gh flags'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
