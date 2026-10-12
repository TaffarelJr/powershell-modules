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
# Arrange - the whole run
$fake = New-FakeGitHubCli
try {
    # Act
    Restart-GitHubWorkflowRun -RunId 123 -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'rerun', '123', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'Without options, the whole run reruns'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a run's failed jobs, with debug logging
$fake = New-FakeGitHubCli
try {
    # Act
    Restart-GitHubWorkflowRun -RunId 123 -Failed -DebugLogging
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'rerun', '123', '--failed', '--debug') -Actual $call.Arguments `
        -Message '-Failed and -DebugLogging become their gh flags'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - one job, with debug logging
$fake = New-FakeGitHubCli
try {
    # Act
    Restart-GitHubWorkflowRun -Job 456 -DebugLogging -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'rerun', '--job', '456', '--debug', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'A job is rerun by its id alone, which gh finds the run of'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - objects piped in with -Job, which then only name the repository:
# one with only a Repository, a run, and a job
$piped = @(
    [PSCustomObject]@{ Repository = 'c/d' }
    [PSCustomObject]@{ DatabaseId = 77; Url = 'https://github.com/c/d/actions/runs/77'; Repository = 'c/d' }
    [PSCustomObject]@{
        DatabaseId = 9
        Steps      = @()
        Url        = 'https://github.com/c/d/actions/runs/77/job/9'
        Repository = 'c/d'
    }
)
$fake = New-FakeGitHubCli
try {
    # Act
    $piped | Restart-GitHubWorkflowRun -Job 9
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    foreach ($index in 0..2) {
        Assert-Equal -Expected @('run', 'rerun', '--job', '9', '--repo', 'c/d') -Actual $calls[$index].Arguments `
            -Message "Piped object $index with -Job is read for its repository only"
    }
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a run and a job together, which gh would quietly read as the job
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Restart-GitHubWorkflowRun -RunId 123 -Job 456
    } -MessageLike ('-RunId and -Job cannot be used together: gh finds the job''s run itself,' +
        ' and would quietly ignore the one given. Give only one.') `
        -Message 'A run with a job is refused, saying why'
    Assert-Throws -ScriptBlock {
        Restart-GitHubWorkflowRun 123 -Job 456
    } -MessageLike '-RunId and -Job cannot be used together:*' -Message 'as is a run given by position'
    foreach ($id in 5, '5') {
        Assert-Throws -ScriptBlock {
            $id | Restart-GitHubWorkflowRun -Job 456
        } -MessageLike ('-RunId and -Job cannot be used together: gh finds the job''s run itself,' +
            ' and would quietly ignore the one given. Give only one.') `
            -Message "and a bare run id piped in ($($id.GetType().Name)), which names no repository"
    }
    Assert-Throws -ScriptBlock {
        Restart-GitHubWorkflowRun -Job 456 -Failed
    } -MessageLike ('-Failed and -Job cannot be used together: one job has no failed jobs to pick out,' +
        ' so gh would quietly ignore it. Give only one.') `
        -Message 'as is a job with -Failed, which gh ignores for a job'
    Assert-Throws -ScriptBlock {
        Restart-GitHubWorkflowRun -DebugLogging
    } -MessageLike 'Give -RunId, or -Job for one job.' -Message 'A call naming neither a run nor a job is refused'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ DatabaseId = 77; Url = 'https://github.com/c/d/actions/runs/77'; Repository = 'c/d' } |
            Restart-GitHubWorkflowRun -Job 9 -Repository 'x/y'
    } -MessageLike 'Job 9 is in c/d, but -Repository names x/y: give one or the other.' `
        -Message 'A run piped in with -Job and a -Repository naming another repository throws the mismatch'
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ DatabaseId = 5; Url = 'https://github.com/c/d/releases/tag/v1'; Repository = 'c/d' } |
            Restart-GitHubWorkflowRun -Job 9
    } -MessageLike ("The object piped in is not a workflow run: its Url 'https://github.com/c/d/releases/tag/v1'" +
        " is not a workflow run's. Give a run Get-GitHubWorkflowRun returned, or its DatabaseId.") `
        -Message 'A release piped in with -Job is refused, in the same words as Get-GitHubWorkflowRunLog'

    # Assert
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'before gh is called'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - what tab completion and the syntax offer
$line = 'Restart-GitHubWorkflowRun -'

# Act
$offered = @((TabExpansion2 -inputScript $line -cursorColumn $line.Length).CompletionMatches.CompletionText)
$syntax = @((Get-Command Restart-GitHubWorkflowRun -Syntax) -split '\r?\n' | Where-Object { $_ -match '\S' })

# Assert
foreach ($name in '-RunId', '-Failed', '-Job', '-Repository', '-Verbose') {
    Assert-That -Condition ($offered -contains $name) -Message "Tab completion offers $name"
}

Assert-Equal -Expected 1 -Actual $syntax.Count `
    -Message 'The syntax has one form, so it advertises no refused combination'

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every other parameter, for a run and for a job, and
# with runs piped in
$fake = New-FakeGitHubCli
try {
    $runs = @(
        [PSCustomObject]@{ DatabaseId = 1; Repository = 'https://user:SENTINEL@github.com/a/b' }
        [PSCustomObject]@{ DatabaseId = 2 }
    )

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Restart-GitHubWorkflowRun -RunId 123 -Failed -DebugLogging -Repository 'o/r' -WhatIf
        Restart-GitHubWorkflowRun -Job 456 -DebugLogging -Repository 'o/r' -WhatIf
        $runs | Restart-GitHubWorkflowRun -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Rerun failed jobs" on target "o/r workflow run 123".'
        'What if: Performing the operation "Rerun job" on target "o/r job 456".'
        'What if: Performing the operation "Rerun workflow run" on target "a/b workflow run 1".'
        'What if: Performing the operation "Rerun workflow run" on target "workflow run 2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names each run or job and what is rerun, with no token'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Restart-GitHubWorkflowRun -Job 456 -Failed -WhatIf
    } -MessageLike '-Failed and -Job cannot be used together:*' `
        -Message 'With -WhatIf, a refused combination still throws'

    # Act
    Restart-GitHubWorkflowRun -RunId 123 -Failed -DebugLogging -Repository 'o/r' -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'rerun', '123', '--failed', '--debug', '--repo', 'o/r') -Actual $call.Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
