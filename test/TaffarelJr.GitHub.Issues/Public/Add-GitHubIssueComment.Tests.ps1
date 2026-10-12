#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Issues/TaffarelJr.GitHub.Issues.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a new comment
$fake = New-FakeGitHubCli
try {
    # Act
    Add-GitHubIssueComment -Issue 12 -Body "Hi`nthere" -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'comment', '12', '--body-file', '-', '--repo', 'o/r') -Actual $call.Arguments -Message 'The body is read from standard input'
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
    Add-GitHubIssueComment -Issue 12 -Body 'Updated' -EditLast -CreateIfNone
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'comment', '12', '--body-file', '-', '--edit-last', '--create-if-none') -Actual $call.Arguments -Message '-EditLast and -CreateIfNone become their gh flags'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - issues from the pipeline, same body
$fake = New-FakeGitHubCli
try {
    # Act
    @('1', '2') | Add-GitHubIssueComment -Body 'Ping'
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped issue gets its own comment call'
    Assert-Equal -Expected @('issue', 'comment', '2', '--body-file', '-') -Actual $calls[1].Arguments -Message 'The second piped issue is commented on too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
