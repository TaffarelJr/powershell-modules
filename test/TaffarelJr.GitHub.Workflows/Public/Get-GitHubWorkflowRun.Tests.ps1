#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

$fields = 'attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,name,number,' +
'startedAt,status,updatedAt,url,workflowDatabaseId,workflowName'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one run with its jobs
$json = '{"databaseId":123,"status":"completed","conclusion":"success",' +
'"jobs":[{"name":"build","conclusion":"success"}]}'
$fake = New-FakeGitHubCli -Output @($json)
try {
    # Act
    $run = Get-GitHubWorkflowRun -RunId 123 -Attempt 2 -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'view', '123', '--json', "$fields,jobs", '--attempt', '2', '--repo', 'o/r') `
        -Actual $call.Arguments `
        -Message 'The id is positional, jobs are included, and -Attempt becomes --attempt'
    Assert-Equal -Expected 'success' -Actual $run.Conclusion `
        -Message 'The run comes back as one object with PascalCase fields'
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
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'view', '7', '--json', "$fields,jobs") -Actual $call.Arguments `
        -Message 'The DatabaseId property binds from the pipeline as -RunId'
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
    $filters = @{
        Workflow = 'ci.yml'
        Branch   = 'main'
        Commit   = 'abc'
        Trigger  = 'push'
        Status   = 'success'
        User     = 'me'
        Created  = '>=2026-01-01'
        All      = $true
        Limit    = 1
    }
    $runs = Get-GitHubWorkflowRun -List @filters -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    $expected = @(
        'run', 'list', '--json', $fields, '--workflow', 'ci.yml', '--branch=main', '--commit=abc'
        '--event=push', '--status=success', '--user=me', '--created=>=2026-01-01', '--all'
        '--limit', '1', '--repo', 'o/r'
    )
    Assert-Equal -Expected $expected -Actual $call.Arguments `
        -Message 'Each filter becomes its gh flag, its value joined to it'
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
    Assert-That -Condition ($runs -isnot [array]) `
        -Message 'A single listed run is written as that one object, not wrapped in an array'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - workflows piped in to narrow a listing, as Get-GitHubWorkflow
# returns them
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    @(
        [PSCustomObject]@{ Id = 42; Name = 'CI'; Path = '.github/workflows/ci.yml' }
        [PSCustomObject]@{ Id = 132478870; Path = 'dynamic/dependabot/dependabot-updates' }
    ) | Get-GitHubWorkflowRun -List | Out-Null
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count `
        -Message 'Each piped workflow''s runs are listed in a call of their own'
    Assert-Equal -Expected @('run', 'list', '--json', $fields, '--workflow', '132478870') -Actual $calls[1].Arguments `
        -Message 'A piped workflow is named by its Id, so a dynamic workflow is found too'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - where each listed run came from: -Repository, its Url, or neither
$json = '[{"databaseId":1,"url":"https://github.com/o/r/actions/runs/1"},{"databaseId":2}]'
$fake = New-FakeGitHubCli -Output @($json)
try {
    # Act
    $given = @(Get-GitHubWorkflowRun -List -Repository 'other/repo')
    $found = @(Get-GitHubWorkflowRun -List)

    # Assert
    Assert-Equal -Expected @('other/repo', 'other/repo') -Actual @($given.ForEach('Repository')) `
        -Message 'Each run carries the -Repository it was read from'
    Assert-Equal -Expected 'o/r' -Actual $found[0].Repository `
        -Message 'Without -Repository, a run carries the repository in its Url, as OWNER/REPO'
    Assert-That -Condition ($null -ne $found[1].PSObject.Properties['Repository'] -and $null -eq $found[1].Repository) `
        -Message 'and one of unknown origin carries a $null Repository'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the same repository named by a URL, by OWNER/REPO, and by the run's Url, and one on another host
$json = '[{"databaseId":1,"url":"https://github.com/o/r/actions/runs/1"}]'
$fake = New-FakeGitHubCli -Output @($json)
try {
    # Act
    $viaUrl = @(Get-GitHubWorkflowRun -List -Repository 'https://github.com/o/r.git')
    $viaName = @(Get-GitHubWorkflowRun -List -Repository 'o/r')
    $viaRun = @(Get-GitHubWorkflowRun -List)
    $other = @(Get-GitHubWorkflowRun -List -Repository 'https://x-access-token:SENTINEL@ghe.example.com/o/r')

    # Assert
    $names = @($viaUrl.Repository, $viaName.Repository, $viaRun.Repository)
    Assert-Equal -Expected @('o/r', 'o/r', 'o/r') -Actual $names `
        -Message 'Where-Object Repository -EQ OWNER/REPO finds a run however its repository was named'
    Assert-Equal -Expected 'ghe.example.com/o/r' -Actual $other[0].Repository `
        -Message 'A run on another host carries HOST/OWNER/REPO, with no credential'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a workflow listed from another repository, piped in to narrow
# a listing
$fake = New-FakeGitHubCli -Output @('[]')
try {
    $workflow = [PSCustomObject]@{ Id = 42; Path = '.github/workflows/ci.yml'; Repository = 'other/repo' }

    # Act
    $workflow | Get-GitHubWorkflowRun -List | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'list', '--json', $fields, '--workflow', '42', '--repo', 'other/repo') `
        -Actual $call.Arguments `
        -Message 'A piped workflow''s runs are listed in the repository it came from'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        $workflow | Get-GitHubWorkflowRun -List -Repository 'o/r'
    } -MessageLike 'Workflow 42 is in other/repo, but -Repository names o/r: give one or the other.' `
        -Message 'A -Repository naming another repository throws'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a workflow object passed by name, and a workflow that is $null
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubWorkflowRun -List -Workflow ([PSCustomObject]@{ Id = 7; Path = '.github/workflows/ci.yml' }) | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'list', '--json', $fields, '--workflow', '7') -Actual $call.Arguments `
        -Message '-Workflow reads an object by its Id'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubWorkflowRun -List -Workflow $null
    } -MessageLike '*A workflow was given, but it is $null*' `
        -Message 'A bound $null -Workflow is refused, not taken for every workflow'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - free text that looks like a timestamp: a run-name built from an
# input, and a branch
$json = '{"databaseId":1,"displayTitle":"2026-01-02T03:04:05Z","name":"2026-01-02T03:04:05Z",' +
'"headBranch":"2026-01-02T03:04:05Z","createdAt":"2026-01-02T03:04:05Z"}'
$fake = New-FakeGitHubCli -Output @($json)
try {
    # Act
    $run = Get-GitHubWorkflowRun -RunId 1

    # Assert
    Assert-Equal -Expected '2026-01-02T03:04:05Z' -Actual $run.DisplayTitle `
        -Message 'A title that looks like a timestamp stays the text it is'
    Assert-Equal -Expected '2026-01-02T03:04:05Z' -Actual $run.Name -Message 'as does a name'
    Assert-Equal -Expected '2026-01-02T03:04:05Z' -Actual $run.HeadBranch -Message 'and a branch'
    Assert-That -Condition ($run.CreatedAt -is [datetime]) -Message 'while a real timestamp field is a [datetime]'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - free text that gh could read as an option
$fake = New-FakeGitHubCli -Output @('[]')
try {
    # Act
    Get-GitHubWorkflowRun -List -Branch '--' -User '-x' | Out-Null
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'list', '--json', $fields, '--branch=--', '--user=-x') -Actual $call.Arguments `
        -Message 'A filter value is joined to its flag, so gh never reads it as an option'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - filters given blank, as a variable that came back empty gives them
$fake = New-FakeGitHubCli
try {
    foreach ($name in 'Branch', 'Commit', 'Trigger', 'Status', 'User', 'Created') {
        $filter = @{ $name = '' }

        # Act / Assert
        Assert-Throws -ScriptBlock {
            Get-GitHubWorkflowRun -List @filter
        } -MessageLike "-$name was given but is blank, so it would filter nothing. Give a value, or leave -$name off." `
            -Message "A blank -$name is refused, not dropped to list every run"
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a limit and an attempt that ask for nothing
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubWorkflowRun -List -Limit 0
    } -MessageLike "*'Limit'*minimum allowed range of 1*" `
        -Message 'A limit below 1 is refused, not taken for gh''s default'
    Assert-Throws -ScriptBlock {
        Get-GitHubWorkflowRun -RunId 123 -Attempt 0
    } -MessageLike "*'Attempt'*minimum allowed range of 1*" `
        -Message 'An attempt below 1 is refused, not taken for the latest'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
