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
    Remove-GitHubWorkflowRun -RunId 123 -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'delete', '123', '--repo', 'o/r') -Actual $call.Arguments `
        -Message 'The id is positional and the repository goes through --repo'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - runs piped in by DatabaseId
$fake = New-FakeGitHubCli
try {
    # Act
    @([PSCustomObject]@{ DatabaseId = 1 }, [PSCustomObject]@{ DatabaseId = 2 }) | Remove-GitHubWorkflowRun
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped run is deleted in its own call'
    Assert-Equal -Expected @('run', 'delete', '2') -Actual $calls[1].Arguments `
        -Message 'The DatabaseId property binds from the pipeline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every other parameter, and with runs piped in
$fake = New-FakeGitHubCli
try {
    $runs = @([PSCustomObject]@{ DatabaseId = 1; Repository = 'a/b' }, [PSCustomObject]@{ DatabaseId = 2 })

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Remove-GitHubWorkflowRun -RunId 123 -Repository 'o/r' -WhatIf
        $runs | Remove-GitHubWorkflowRun -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete workflow run" on target "o/r workflow run 123".'
        'What if: Performing the operation "Delete workflow run" on target "a/b workflow run 1".'
        'What if: Performing the operation "Delete workflow run" on target "workflow run 2".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages -Message '-WhatIf names each run'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is never called'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a token in a repository object's Url and in a run's Url
$fake = New-FakeGitHubCli
try {
    $run = [PSCustomObject]@{ DatabaseId = 5; Url = 'https://user:SENTINEL@ghe.example.com/o/r/actions/runs/5' }
    $repository = [PSCustomObject]@{ Url = 'https://user:SENTINEL@github.com/o/r' }

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Remove-GitHubWorkflowRun -RunId 4 -Repository $repository -WhatIf
        $run | Remove-GitHubWorkflowRun -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Delete workflow run" on target "o/r workflow run 4".'
        'What if: Performing the operation "Delete workflow run" on target "ghe.example.com/o/r workflow run 5".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names the repository as [HOST/]OWNER/REPO'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match 'SENTINEL') -Message 'and never shows the token'
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
        [PSCustomObject]@{ DatabaseId = 9; Steps = @() } | Remove-GitHubWorkflowRun -WhatIf
    } -MessageLike "A job is not a run: its DatabaseId is the job's own, not its run's. Give the run it belongs to." `
        -Message 'With -WhatIf, a job piped in is still refused'

    # Act
    Remove-GitHubWorkflowRun -RunId 123 -Repository 'o/r' -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('run', 'delete', '123', '--repo', 'o/r') -Actual $call.Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
