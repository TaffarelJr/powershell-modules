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
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Stop-GitHubWorkflowRun -RunId 123 -Force -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'cancel', '123', '--force', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The id is positional and -Force becomes --force'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - runs piped in by DatabaseId, as a listing returns them
$fake = New-FakeGitHubCli
try {
    # Act
    @([PSCustomObject]@{ DatabaseId = 1 }, [PSCustomObject]@{ DatabaseId = 2 }) | Stop-GitHubWorkflowRun
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped run is canceled in its own call'
    Assert-Equal -Expected @('run', 'cancel', '2') -Actual $calls[1].Arguments `
        -Message 'The DatabaseId property binds from the pipeline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - gh cannot cancel the run
$fake = New-FakeGitHubCli -ErrorOutput @('HTTP 409: Cannot cancel a workflow run that is completed.') -ExitCode 1
try {
    # Act / Assert
    Assert-Throws -ScriptBlock {
        Stop-GitHubWorkflowRun -RunId 5
    } -MessageLike 'Canceling workflow run 5 failed:*HTTP 409: Cannot cancel*' `
        -Message 'A failure throws with gh''s message, under the activity''s en-US spelling'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every other parameter, and with runs piped in
$fake = New-FakeGitHubCli
try {
    $runs = @(
        [PSCustomObject]@{ DatabaseId = 1; Repository = 'https://user:SENTINEL@github.com/a/b' }
        [PSCustomObject]@{ DatabaseId = 2 }
    )

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Stop-GitHubWorkflowRun -RunId 123 -Force -Repository 'o/r' -WhatIf
        $runs | Stop-GitHubWorkflowRun -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Force-cancel workflow run" on target "o/r workflow run 123".'
        'What if: Performing the operation "Cancel workflow run" on target "a/b workflow run 1".'
        'What if: Performing the operation "Cancel workflow run" on target "workflow run 2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names each run and whether it is forced, with no token'
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
        [PSCustomObject]@{ DatabaseId = 9; Steps = @() } | Stop-GitHubWorkflowRun -WhatIf
    } -MessageLike "A job is not a run: its DatabaseId is the job's own, not its run's. Give the run it belongs to." `
        -Message 'With -WhatIf, a job piped in is still refused'

    # Act
    Stop-GitHubWorkflowRun -RunId 123 -Force -Repository 'o/r' -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'cancel', '123', '--force', '--repo', 'o/r') -Actual $call.Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
