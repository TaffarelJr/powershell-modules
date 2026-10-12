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
# Arrange - a title and a multi-line body
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/issues/9')
try {
    # Act
    $url = New-GitHubIssue -Title 'Bug' -Body "Line 1`n`nLine 3" -Label @('bug') -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'create', '--title', 'Bug', '--body-file', '-', '--label', 'bug', '--repo', 'o/r') -Actual $call.Arguments -Message 'The body is read from standard input; the rest become their gh flags'
    Assert-Equal -Expected "Line 1`n`nLine 3" -Actual $call.StdIn -Message 'The body itself is what gets piped, blank lines included'
    Assert-Equal -Expected 'https://github.com/o/r/issues/9' -Actual $url -Message "The new issue's URL is returned"
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every other option
$fake = New-FakeGitHubCli -Output @('https://github.com/o/r/issues/10')
try {
    # Act
    New-GitHubIssue -Title 'Sub' -Assignee @('@me', 'bob') -Milestone 'v1' -Project @('Roadmap') -Template 'bug.md' -Type 'Bug' -Parent 5 -BlockedBy @(1, 2) -Blocking @(3) | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('issue', 'create', '--title', 'Sub', '--assignee', '@me', '--assignee', 'bob', '--milestone', 'v1', '--project', 'Roadmap', '--template', 'bug.md', '--type', 'Bug', '--parent', '5', '--blocked-by', '1', '--blocked-by', '2', '--blocking', '3') -Actual $call.Arguments -Message 'Each option becomes its gh flag, one per list element'
    Assert-Equal -Expected '' -Actual $call.StdIn -Message 'Nothing is piped without -Body'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
