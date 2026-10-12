#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a full diff
$fake = New-FakeGitHubCli -Output @('diff --git a/x b/x', '+added')
try {
    # Act
    $diff = @(Get-GitHubPullRequestDiff -PullRequest 12 -Repository 'o/r')
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'diff', '12', '--color', 'never', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The pull request is positional, color is always off, and the repository goes through --repo'
    Assert-Equal -Expected @('diff --git a/x b/x', '+added') -Actual $diff -Message 'The diff comes back as its lines'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - just one changed file's name, with exclusions
$fake = New-FakeGitHubCli -Output @('src/only.ps1')
try {
    # Act
    $names = Get-GitHubPullRequestDiff -NameOnly -Patch -Exclude @('*.md', 'generated/*')
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal `
        -Expected @(
            'pr', 'diff', '--color', 'never', '--name-only', '--patch', '--exclude=*.md', '--exclude=generated/*'
        ) `
        -Actual $call.Arguments `
        -Message 'Each option becomes its gh flag, one --exclude per pattern'
    Assert-Equal -Expected 'src/only.ps1' -Actual $names -Message 'A single changed file comes back as that name'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh fails for the current branch's pull request
$fake = New-FakeGitHubCli -ErrorOutput @('no pull requests found for branch "main"') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestDiff
    } -MessageLike "Reading the diff of the current branch's pull request failed*no pull requests found*" `
        -Message 'A failure names the current branch''s pull request when none was given'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a blank pattern among those to leave out
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubPullRequestDiff -PullRequest 4 -Exclude '*.md', ''
    } -MessageLike '*-Exclude has a blank element, which would leave nothing out. Give patterns, or leave -Exclude out.' `
        -Message 'A blank pattern is refused, not sent as an empty --exclude'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
