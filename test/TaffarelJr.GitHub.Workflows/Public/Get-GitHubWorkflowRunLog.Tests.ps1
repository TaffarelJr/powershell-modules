#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a whole run's log
$fake = New-FakeGitHubCli -Output @('build  Set up job  line 1', 'build  Set up job  line 2')
try {
    # Act
    $log = @(Get-GitHubWorkflowRunLog -RunId 123 -Repository 'o/r')
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'view', '123', '--log', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The full log is asked for by default'
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
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'view', '--job', '456', '--log-failed', '--attempt', '1') -Actual $call.Arguments `
        -Message 'Without -RunId the job alone selects the log; -Failed asks for failed steps only'
    Assert-Equal -Expected 'error: it broke' -Actual $log -Message 'A single log line comes back as that line'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - objects piped in with -Job, which then only name the repository:
# one with only a Repository, a run, and the job itself
$piped = @(
    [PSCustomObject]@{ Repository = 'c/d' }
    [PSCustomObject]@{ DatabaseId = 77; Url = 'https://github.com/c/d/actions/runs/77'; Repository = 'c/d' }
    [PSCustomObject]@{
        DatabaseId = 99
        Steps      = @()
        Url        = 'https://github.com/c/d/actions/runs/77/job/99'
        Repository = 'c/d'
    }
)
$fake = New-FakeGitHubCli -Output @('line')
try {
    # Act
    $piped | Get-GitHubWorkflowRunLog -Job 99 | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    foreach ($index in 0..2) {
        Assert-Equal -Expected @('run', 'view', '--job', '99', '--log', '--repo', 'c/d') `
            -Actual $calls[$index].Arguments `
            -Message "Piped object $index with -Job is read for its repository only, its DatabaseId unused"
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare run id with -Job, by name and piped
$fake = New-FakeGitHubCli -Output @('line')
try {
    # Act
    Get-GitHubWorkflowRunLog -RunId 5 -Job 9 | Out-Null
    5 | Get-GitHubWorkflowRunLog -Job 9 | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('run', 'view', '5', '--job', '9', '--log') -Actual $calls[0].Arguments `
        -Message 'A run id given with -Job narrows gh''s lookup of the job'
    Assert-Equal -Expected $calls[0].Arguments -Actual $calls[1].Arguments `
        -Message 'and a bare run id piped in is sent the same, not dropped'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a run piped in with -Job and a -Repository naming another
# repository, and a release piped in with -Job
$run = [PSCustomObject]@{ DatabaseId = 77; Url = 'https://github.com/c/d/actions/runs/77'; Repository = 'c/d' }
$release = [PSCustomObject]@{
    DatabaseId = 5
    Url        = 'https://github.com/c/d/releases/tag/v1'
    Repository = 'c/d'
}
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        $run | Get-GitHubWorkflowRunLog -Job 9 -Repository 'x/y'
    } -MessageLike 'Job 9 is in c/d, but -Repository names x/y: give one or the other.' `
        -Message 'The mismatch names the job, since no run was asked for'
    Assert-Throws -ScriptBlock {
        $release | Get-GitHubWorkflowRunLog -Job 9
    } -MessageLike ("The object piped in is not a workflow run: its Url 'https://github.com/c/d/releases/tag/v1'" +
        " is not a workflow run's. Give a run Get-GitHubWorkflowRun returned, or its DatabaseId.") `
        -Message 'A release piped in with -Job is refused, as its help says'

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
