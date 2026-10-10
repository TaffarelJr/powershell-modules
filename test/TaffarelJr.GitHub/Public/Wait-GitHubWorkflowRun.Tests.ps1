#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$fields = 'attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,name,number,startedAt,status,updatedAt,url,workflowDatabaseId,workflowName,jobs'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the fake answers both the watch and the read-back with the run
$fake = New-FakeGitHubCli -Output @('{"databaseId":123,"status":"completed","conclusion":"success"}')
try {
    # Act
    $run = Wait-GitHubWorkflowRun -Id 123 -Interval 5 -Repository 'o/r'
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'The run is watched, then read back'
    Assert-Equal -Expected @('run', 'watch', '123', '--interval', '5', '--repo', 'o/r') -Actual $calls[0].Arguments -Message 'The watch names the run and the poll interval'
    Assert-Equal -Expected @('run', 'view', '123', '--json', $fields, '--repo', 'o/r') -Actual $calls[1].Arguments -Message 'The finished run is read back with its jobs'
    Assert-Equal -Expected 'success' -Actual $run.Conclusion -Message 'The finished run is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a failed run, which gh's watch reports through its exit code
$fake = New-FakeGitHubCli -Output @('{"databaseId":7,"status":"completed","conclusion":"failure"}') -ExitCode 1
try {
    # Act / Assert - the read-back also exits 1 here, so the fake cannot
    # answer both legs; what matters is that the watch's exit code alone
    # does not throw before the read-back is attempted
    Assert-Throws -ScriptBlock { Wait-GitHubWorkflowRun -Id 7 } -Message 'A read-back that fails still throws'
    $calls = Get-FakeGitHubCall -Fixture $fake
    Assert-Equal -Expected 2 -Actual $calls.Count -Message "The watch's own non-zero exit does not stop the read-back from being attempted"
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
