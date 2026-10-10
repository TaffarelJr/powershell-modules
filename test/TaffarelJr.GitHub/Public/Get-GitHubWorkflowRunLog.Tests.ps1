#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a whole run's log
$fake = New-FakeGitHubCli -Output @('build  Set up job  line 1', 'build  Set up job  line 2')
try {
    # Act
    $log = Get-GitHubWorkflowRunLog -Id 123 -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'view', '123', '--log', '--repo', 'o/r') -Actual $call.Arguments -Message 'The full log is asked for by default'
    Assert-Equal -Expected 2 -Actual $log.Count -Message 'The log comes back as its lines'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - only one job's failed steps, on an earlier attempt
$fake = New-FakeGitHubCli -Output @('error: it broke')
try {
    # Act
    $log = Get-GitHubWorkflowRunLog -Job 456 -Failed -Attempt 1
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'view', '--job', '456', '--log-failed', '--attempt', '1') -Actual $call.Arguments -Message 'Without -Id the job alone selects the log; -Failed asks for failed steps only'
    Assert-That -Condition ($log -is [array]) -Message 'A single log line is still returned as an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
