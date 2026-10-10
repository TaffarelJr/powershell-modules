#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

$fields = 'attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,name,number,startedAt,status,updatedAt,url,workflowDatabaseId,workflowName'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one run with its jobs
$fake = New-FakeGitHubCli -Output @('{"databaseId":123,"status":"completed","conclusion":"success","jobs":[{"name":"build","conclusion":"success"}]}')
try {
    # Act
    $run = Get-GitHubWorkflowRun -Id 123 -Attempt 2 -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'view', '123', '--json', "$fields,jobs", '--attempt', '2', '--repo', 'o/r') -Actual $call.Arguments -Message 'The id is positional, jobs are included, and -Attempt becomes --attempt'
    Assert-Equal -Expected 'success' -Actual $run.Conclusion -Message 'The run comes back as one object with PascalCase fields'
    Assert-Equal -Expected 'build' -Actual $run.Jobs[0].Name -Message 'Jobs are re-cased too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a run piped in by its DatabaseId property, as a listing returns it
$fake = New-FakeGitHubCli -Output @('{"databaseId":7}')
try {
    # Act
    $run = [PSCustomObject]@{ DatabaseId = 7 } | Get-GitHubWorkflowRun
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'view', '7', '--json', "$fields,jobs") -Actual $call.Arguments -Message 'The DatabaseId property binds from the pipeline as -Id'
    Assert-Equal -Expected 7 -Actual $run.DatabaseId -Message 'The piped run is described'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - listing with every filter
$fake = New-FakeGitHubCli -Output @('[{"databaseId":1,"headSha":"abc"},{"databaseId":2,"headSha":"def"}]')
try {
    # Act
    $runs = Get-GitHubWorkflowRun -List -Workflow 'ci.yml' -Branch 'main' -Commit 'abc' -Trigger 'push' -Status 'success' -User 'me' -Created '>=2026-01-01' -All -Limit 1 -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'list', '--json', $fields, '--workflow', 'ci.yml', '--branch', 'main', '--commit', 'abc', '--event', 'push', '--status', 'success', '--user', 'me', '--created', '>=2026-01-01', '--all', '--limit', '1', '--repo', 'o/r') -Actual $call.Arguments -Message 'Each filter becomes its gh flag'
    Assert-Equal -Expected 2 -Actual $runs.Count -Message 'Every listed run is returned'
    Assert-Equal -Expected 'def' -Actual $runs[1].HeadSha -Message 'List fields are PascalCase'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a single listed run
$fake = New-FakeGitHubCli -Output @('[{"databaseId":1}]')
try {
    # Act
    $runs = Get-GitHubWorkflowRun -List

    # Assert
    Assert-That -Condition ($runs -is [array]) -Message 'A single listed run is still returned as an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
