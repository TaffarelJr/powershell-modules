#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,name,number,startedAt,status,updatedAt,url,workflowDatabaseId,workflowName,jobs'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the run is already completed on the very first poll,
# so the wait returns before ever sleeping
$fake = New-FakeGitHubCli -Output @('{"databaseId":123,"status":"completed","conclusion":"success"}')
try {
    # Act
    $run = Wait-GitHubWorkflowRun -Id 123 -Repository 'o/r'
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'The run is polled once, then read back in full'
    Assert-Equal -Expected @('run', 'view', '123', '--json', 'status', '--repo', 'o/r') -Actual $calls[0].Arguments -Message 'The poll asks only for status'
    Assert-Equal -Expected @('run', 'view', '123', '--json', $fields, '--repo', 'o/r') -Actual $calls[1].Arguments -Message 'The finished run is read back with its jobs'
    Assert-Equal -Expected 'success' -Actual $run.Conclusion -Message 'The finished run is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the run never leaves in_progress, so the wait times out and
# returns the run as it last stood
$fake = New-FakeGitHubCli -Output @('{"databaseId":7,"status":"in_progress"}')
try {
    # Act
    $run = Wait-GitHubWorkflowRun -Id 7 -TimeoutSeconds 1 -PollSeconds 1

    # Assert
    Assert-Equal -Expected 'in_progress' -Actual $run.Status -Message 'A run still running at the deadline is returned as still in_progress, not thrown'
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
    Assert-Throws -ScriptBlock { Wait-GitHubWorkflowRun -Id 9 -TimeoutSeconds 60 -PollSeconds 1 } `
        -Message 'Three consecutive unreadable polls throws rather than waiting out the full timeout'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
