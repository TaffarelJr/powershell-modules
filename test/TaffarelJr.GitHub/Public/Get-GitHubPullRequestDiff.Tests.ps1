#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a full diff
$fake = New-FakeGitHubCli -Output @('diff --git a/x b/x', '+added')
try {
    # Act
    $diff = Get-GitHubPullRequestDiff -PullRequest 12 -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'diff', '12', '--repo', 'o/r') -Actual $call.Arguments -Message 'The pull request is positional and the repository goes through --repo'
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
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'diff', '--name-only', '--patch', '--exclude', '*.md', '--exclude', 'generated/*') -Actual $call.Arguments -Message 'Each option becomes its gh flag, one --exclude per pattern'
    Assert-That -Condition ($names -is [array]) -Message 'A single changed file is still returned as an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
