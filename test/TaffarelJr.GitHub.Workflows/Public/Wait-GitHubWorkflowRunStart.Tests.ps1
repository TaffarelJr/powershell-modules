#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the very first poll already finds a run not in -Before,
# so the wait returns before ever sleeping
$fake = New-FakeGitHubCli -Output @('[{"databaseId":9},{"databaseId":5}]')
try {
    # Act
    $id = Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @(5) -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected 9 -Actual $id -Message 'The run id not present in -Before is returned'
    Assert-Equal -Expected @('run', 'list', '--workflow', 'ci.yml', '--limit', '20', '--json', 'databaseId', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'gh is asked to list the workflow''s recent runs'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - every poll succeeds, but never with a run outside -Before,
# so the wait times out and returns $null
$fake = New-FakeGitHubCli -Output @('[{"databaseId":5}]')
try {
    # Act
    $id = Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @(5) -TimeoutSeconds 1 -PollSeconds 1

    # Assert
    Assert-That -Condition ($null -eq $id) -Message 'No fresh run within the timeout returns $null'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh fails on every poll, so three in a row throws
# instead of letting the wait run out the clock
$fake = New-FakeGitHubCli -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock { Wait-GitHubWorkflowRunStart -Workflow 'ci.yml' -Before @() -TimeoutSeconds 60 -PollSeconds 1 } `
        -Message 'Three consecutive unreadable polls throws rather than waiting out the full timeout'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
