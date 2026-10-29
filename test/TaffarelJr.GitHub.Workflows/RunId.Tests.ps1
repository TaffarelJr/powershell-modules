#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

# Every function that takes a run by its id, and the gh call a run piped in
# by its DatabaseId - as a listing returns it - becomes.
$fields = 'attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,name,number,' +
'startedAt,status,updatedAt,url,workflowDatabaseId,workflowName'
$functions = @(
    @{ Name = 'Get-GitHubWorkflowRun'; Expected = @('run', 'view', '77', '--json', "$fields,jobs") }
    @{ Name = 'Get-GitHubWorkflowRunLog'; Expected = @('run', 'view', '77', '--log') }
    @{ Name = 'Remove-GitHubWorkflowRun'; Expected = @('run', 'delete', '77') }
    @{ Name = 'Restart-GitHubWorkflowRun'; Expected = @('run', 'rerun', '77') }
    @{ Name = 'Save-GitHubWorkflowRunArtifact'; Expected = @('run', 'download', '77') }
    @{ Name = 'Stop-GitHubWorkflowRun'; Expected = @('run', 'cancel', '77') }
    @{ Name = 'Wait-GitHubWorkflowRun'; Expected = @('run', 'view', '77', '--json', 'status') }
)
$finished = '{"databaseId":77,"status":"completed"}'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - ids that are no run's
$fake = New-FakeGitHubCli
try {
    foreach ($function in $functions) {
        $name = $function.Name

        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $name -RunId 0
        } -MessageLike "*'RunId'*minimum allowed range of 1*" -Message "${name}: an id of 0 is refused"
        Assert-Throws -ScriptBlock {
            & $name -RunId -5
        } -MessageLike "*'RunId'*minimum allowed range of 1*" `
            -Message "${name}: a negative id is refused, which gh would read as an option"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a run piped in by its DatabaseId, as a listing returns it
foreach ($function in $functions) {
    $fake = New-FakeGitHubCli -Output @($finished)
    try {
        # Act
        [PSCustomObject]@{ DatabaseId = 77; Status = 'completed' } | & $function.Name | Out-Null
        $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

        # Assert
        Assert-Equal -Expected $function.Expected -Actual $call.Arguments `
            -Message "$($function.Name): a piped run binds by its DatabaseId"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a bare run id piped in
foreach ($function in $functions) {
    $fake = New-FakeGitHubCli -Output @($finished)
    try {
        # Act
        77 | & $function.Name | Out-Null
        $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

        # Assert
        Assert-Equal -Expected $function.Expected -Actual $call.Arguments `
            -Message "$($function.Name): a piped number is the run id"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - objects whose Id is not a run's: a workflow's and a cache's
$foreign = @(
    @{ Kind = 'workflow'; Object = [PSCustomObject]@{ Id = 4242; Name = 'CI'; Path = '.github/workflows/ci.yml' } }
    @{ Kind = 'cache'; Object = [PSCustomObject]@{ Id = [long]5000000001; Key = 'npm-abc'; SizeInBytes = 10 } }
)
$fake = New-FakeGitHubCli -Output @($finished)
try {
    foreach ($function in $functions) {
        foreach ($case in $foreign) {
            $name = $function.Name
            $object = $case.Object

            # Act / Assert
            Assert-Throws -ScriptBlock {
                $object | & $name
            } -MessageLike '*input object cannot be bound*' `
                -Message "${name}: a piped $($case.Kind) object is refused, not read as a run by its Id"
        }
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a job, as a run's Jobs report it: its DatabaseId is the job's
$job = [PSCustomObject]@{
    DatabaseId = 999
    Name       = 'build'
    Steps      = @()
    Url        = 'https://github.com/o/r/actions/runs/77/job/999'
}
$jobByUrl = [PSCustomObject]@{ DatabaseId = 999; Url = 'https://github.com/o/r/actions/runs/77/job/999' }
$fake = New-FakeGitHubCli -Output @($finished)
try {
    foreach ($function in $functions) {
        $name = $function.Name
        foreach ($object in $job, $jobByUrl) {
            # Act / Assert
            Assert-Throws -ScriptBlock {
                $object | & $name
            } -MessageLike '*A job is not a run: its DatabaseId is the job''s own, not its run''s.*' `
                -Message "${name}: a piped job is refused, not read as a run"
        }
    }

    Assert-Throws -ScriptBlock {
        $job | Restart-GitHubWorkflowRun
    } -MessageLike '*To rerun the job, give its DatabaseId to -Job.' `
        -Message 'Restart-GitHubWorkflowRun says how to rerun a job'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - runs read from another repository, as Get-GitHubWorkflowRun
# returns them: with a Repository, and with only a Url
$listed = [PSCustomObject]@{
    DatabaseId = 77
    Url        = 'https://github.com/other/repo/actions/runs/77'
    Repository = 'other/repo'
}
$urlOnly = [PSCustomObject]@{ DatabaseId = 77; Url = 'https://github.com/other/repo/actions/runs/77' }
foreach ($function in $functions) {
    $fake = New-FakeGitHubCli -Output @($finished)
    try {
        # Act
        $listed | & $function.Name | Out-Null
        $urlOnly | & $function.Name | Out-Null
        $calls = @(Get-FakeGitHubCall -Fixture $fake)

        # Assert
        Assert-Equal -Expected ($function.Expected + @('--repo', 'other/repo')) -Actual $calls[0].Arguments `
            -Message "$($function.Name): a piped run is acted on in the repository it came from"
        Assert-Equal -Expected 'https://github.com/other/repo' -Actual $calls[-1].Arguments[-1] `
            -Message "$($function.Name): one with only a Url, in the repository of its Url"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a run from other/repo with a -Repository naming another one,
# and the same one written another way
foreach ($function in $functions) {
    $fake = New-FakeGitHubCli -Output @($finished)
    try {
        $name = $function.Name

        # Act / Assert
        Assert-Throws -ScriptBlock {
            $listed | & $name -Repository 'o/r'
        } -MessageLike 'Workflow run 77 is in other/repo, but -Repository names o/r: give one or the other.' `
            -Message "${name}: a -Repository naming another repository than the run's throws"
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
            -Message "${name}: before gh is called"

        # Act
        $urlOnly | & $name -Repository 'github.com/Other/Repo' | Out-Null
        $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

        # Assert
        Assert-Equal -Expected ($function.Expected + @('--repo', 'github.com/Other/Repo')) -Actual $call.Arguments `
            -Message "${name}: a -Repository naming the run's own repository is used"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - objects of other kinds that carry a DatabaseId, as
# Get-GitHubRelease and an issue listing return them, and a run whose Url
# names another run
$strangers = @(
    @{
        Kind   = 'release'
        Object = [PSCustomObject]@{
            TagName    = 'v1'
            DatabaseId = 77
            Url        = 'https://github.com/o/r/releases/tag/v1'
            Repository = 'o/r'
        }
        Url    = 'https://github.com/o/r/releases/tag/v1'
    }
    @{
        Kind   = 'issue'
        Object = [PSCustomObject]@{ DatabaseId = 77; Url = 'https://github.com/o/r/issues/77' }
        Url    = 'https://github.com/o/r/issues/77'
    }
    @{
        Kind   = 'run of another id'
        Object = [PSCustomObject]@{ DatabaseId = 77; Url = 'https://github.com/o/r/actions/runs/770' }
        Url    = 'https://github.com/o/r/actions/runs/770'
    }
)
$fake = New-FakeGitHubCli -Output @($finished)
try {
    foreach ($function in $functions) {
        foreach ($case in $strangers) {
            $name = $function.Name
            $object = $case.Object

            # Act / Assert
            Assert-Throws -ScriptBlock {
                $object | & $name
            } -MessageLike ("The object piped in is not a workflow run: its Url '$($case.Url)'" +
                " is not workflow run 77's. Give a run Get-GitHubWorkflowRun returned, or its DatabaseId.") `
                -Message "${name}: a piped $($case.Kind) is refused, not read as a run by its DatabaseId"
        }
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is called for none of them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a cache object as Get-GitHubCache returns it, with a Repository
# that binds by name, piped to the functions whose -RunId is optional
$cache = [PSCustomObject]@{ Id = [long]5000000001; Key = 'npm-abc'; Repository = 'o/r' }
$fake = New-FakeGitHubCli
try {
    foreach ($name in 'Get-GitHubWorkflowRunLog', 'Save-GitHubWorkflowRunArtifact') {
        # Act / Assert
        Assert-Throws -ScriptBlock {
            $cache | & $name
        } -MessageLike ('The object piped in is not a workflow run: it has no DatabaseId.' +
            ' Give a run Get-GitHubWorkflowRun returned, or its DatabaseId.') `
            -Message "${name}: a piped object that binds no run id is refused"
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - an object with only a Repository, piped in with -Job, which then
# names only the repository
$named = [PSCustomObject]@{ Repository = 'c/d' }
$fake = New-FakeGitHubCli
try {
    # Act
    $named | Get-GitHubWorkflowRunLog -Job 9 | Out-Null
    $named | Restart-GitHubWorkflowRun -Job 9
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected @('run', 'view', '--job', '9', '--log', '--repo', 'c/d') -Actual $calls[0].Arguments `
        -Message 'Get-GitHubWorkflowRunLog -Job reads a piped object for its repository only'
    Assert-Equal -Expected @('run', 'rerun', '--job', '9', '--repo', 'c/d') -Actual $calls[1].Arguments `
        -Message 'as does Restart-GitHubWorkflowRun -Job'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a run from another repository, then one of unknown origin, piped
# in one pipeline
foreach ($function in $functions) {
    $fake = New-FakeGitHubCli -Output @($finished)
    try {
        # Act
        @($listed, [PSCustomObject]@{ DatabaseId = 77 }) | & $function.Name | Out-Null
        $calls = @(Get-FakeGitHubCall -Fixture $fake)

        # Assert
        Assert-Equal -Expected $function.Expected -Actual $calls[$calls.Count / 2].Arguments `
            -Message "$($function.Name): a run of unknown origin does not take the previous run's repository"
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the piped object is read in place, so nothing about it is a
# parameter a caller could give
$fake = New-FakeGitHubCli
try {
    foreach ($function in $functions) {
        $name = $function.Name
        foreach ($parameter in 'RunUrl', 'JobSteps', 'Url', 'Steps') {
            $splat = @{ RunId = 77; $parameter = 'x' }

            # Act / Assert
            Assert-Throws -ScriptBlock {
                & $name @splat
            } -MessageLike "*parameter name '$parameter'*" -Message "${name}: -$parameter names nothing"
        }

        # Act / Assert
        Assert-That -Condition ((Get-Command $name -Syntax) -notmatch 'RunUrl|JobSteps') `
            -Message "${name}: the syntax shows no hidden parameter"
        Assert-Throws -ScriptBlock {
            & $name -RunId 77 -Repository $null
        } -MessageLike '-Repository was given, but it is $null - leave it out to use*' `
            -Message "${name}: a -Repository given as `$null is refused"
    }

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - the old parameter name
$fake = New-FakeGitHubCli
try {
    foreach ($function in $functions) {
        $name = $function.Name

        # Act / Assert
        Assert-Throws -ScriptBlock {
            & $name -Id 77
        } -MessageLike "*parameter name 'Id'*" -Message "${name}: -Id names nothing, so no object binds a run by its Id"
    }

    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - jobs that are no job's
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Get-GitHubWorkflowRunLog -Job 0
    } -MessageLike "*'Job'*minimum allowed range of 1*" -Message 'Get-GitHubWorkflowRunLog: a job id of 0 is refused'
    Assert-Throws -ScriptBlock {
        Restart-GitHubWorkflowRun -Job -1
    } -MessageLike "*'Job'*minimum allowed range of 1*" `
        -Message 'Restart-GitHubWorkflowRun: a negative job id is refused'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is called for neither'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
