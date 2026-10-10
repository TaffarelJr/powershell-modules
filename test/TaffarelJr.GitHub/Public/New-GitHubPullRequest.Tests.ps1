#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a title and a multi-line body
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/pull/13')
try {
    # Act
    $url = New-GitHubPullRequest -Title 'Sync template' -Body "Line 1`n`nLine 3" -Base 'main' -Head 'template-sync' -Label @('template sync') -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'create', '--title', 'Sync template', '--body-file', '-', '--base', 'main', '--head', 'template-sync', '--label', 'template sync', '--repo', 'o/r') -Actual $call.Arguments -Message 'The body is read from standard input; the rest become their gh flags'
    Assert-Equal -Expected "Line 1`n`nLine 3" -Actual $call.StdIn -Message 'The body itself is what gets piped, blank lines included'
    Assert-Equal -Expected 'https://github.com/o/r/pull/13' -Actual $url -Message 'The new pull request''s URL is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every other option, filled from commits
$fake = New-FakeGitHubCli -Output @('Warning: 1 uncommitted change', 'https://github.com/o/r/pull/14')
try {
    # Act
    $url = New-GitHubPullRequest -Draft -Assignee @('@me', 'bob') -Reviewer @('org/team') -Milestone 'v1' -Project @('Roadmap') -Template 'pr.md' -Fill -FillFirst -FillVerbose -NoMaintainerEdit -DryRun
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('pr', 'create', '--draft', '--assignee', '@me', '--assignee', 'bob', '--reviewer', 'org/team', '--milestone', 'v1', '--project', 'Roadmap', '--template', 'pr.md', '--fill', '--fill-first', '--fill-verbose', '--no-maintainer-edit', '--dry-run') -Actual $call.Arguments -Message 'Each option becomes its gh flag, one per list element'
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'Nothing is piped without -Body'
    Assert-Equal -Expected 'https://github.com/o/r/pull/14' -Actual $url -Message 'The URL is picked out from among other output lines'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
