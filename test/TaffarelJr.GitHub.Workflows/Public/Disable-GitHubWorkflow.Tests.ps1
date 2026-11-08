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
    Disable-GitHubWorkflow -Workflow 'ci.yml' -Repository 'o/r'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'disable', '--repo', 'o/r', '--', 'ci.yml') -Actual $call.Arguments `
        -Message 'The repository goes through --repo and the workflow comes last, after a --'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - workflows piped in as Get-GitHubWorkflow returns them, a run as a
# listing returns it, and text
$fake = New-FakeGitHubCli
try {
    # Act
    @(
        [PSCustomObject]@{ Id = 1; Name = 'A'; Path = '.github/workflows/a.yml' }
        [PSCustomObject]@{ Id = 132478870; Name = 'Dependabot Updates'; Path = 'dynamic/dependabot/dependabot-updates' }
        [PSCustomObject]@{ DatabaseId = 123; WorkflowName = 'CI'; WorkflowDatabaseId = 777; Status = 'completed' }
        'b.yml'
    ) | Disable-GitHubWorkflow
    $calls = @(Get-FakeGitHubCall -Fixture $fake)

    # Assert
    Assert-Equal -Expected 4 -Actual $calls.Count -Message 'Each piped workflow is disabled in its own call'
    Assert-Equal -Expected @('workflow', 'disable', '--', '1') -Actual $calls[0].Arguments `
        -Message 'A piped workflow is named by its Id'
    Assert-Equal -Expected @('workflow', 'disable', '--', '132478870') -Actual $calls[1].Arguments `
        -Message 'so a dynamic workflow, whose Path gh cannot look up, is found too'
    Assert-Equal -Expected @('workflow', 'disable', '--', '777') -Actual $calls[2].Arguments `
        -Message 'A piped run is read by its WorkflowDatabaseId, not bound as its text'
    Assert-Equal -Expected @('workflow', 'disable', '--', 'b.yml') -Actual $calls[3].Arguments `
        -Message 'and piped text is the workflow itself'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a workflow listed from another repository
$fake = New-FakeGitHubCli
try {
    $workflow = [PSCustomObject]@{ Id = 1; Path = '.github/workflows/a.yml'; Repository = 'other/repo' }

    # Act
    $workflow | Disable-GitHubWorkflow
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'disable', '--repo', 'other/repo', '--', '1') -Actual $call.Arguments `
        -Message 'A piped workflow is acted on in the repository it came from'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        $workflow | Disable-GitHubWorkflow -Repository 'o/r'
    } -MessageLike 'Workflow 1 is in other/repo, but -Repository names o/r: give one or the other.' `
        -Message 'A -Repository naming another repository throws'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a workflow that looks like an option, and objects that name none
$fake = New-FakeGitHubCli
try {
    # Act
    Disable-GitHubWorkflow -Workflow '--web'
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'disable', '--', '--web') -Actual $call.Arguments `
        -Message 'A workflow is an operand whatever it starts with'

    # Act / Assert
    Assert-Throws -ScriptBlock {
        [PSCustomObject]@{ Key = 'npm-abc' } | Disable-GitHubWorkflow
    } -MessageLike '*A workflow object needs an Id, a Path, or a WorkflowDatabaseId*' `
        -Message 'An object that names no workflow is refused'
    Assert-Throws -ScriptBlock {
        Disable-GitHubWorkflow -Workflow $null
    } -MessageLike "*Workflow*null*" -Message 'as is $null'
    Assert-Equal -Expected 1 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and gh is not called for them'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - -WhatIf with every other parameter, and with workflows piped in
$fake = New-FakeGitHubCli
try {
    $workflows = @(
        [PSCustomObject]@{ Id = 1; Path = '.github/workflows/a.yml'; Repository = 'a/b' }
        'b.yml'
    )

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        Disable-GitHubWorkflow -Workflow 'ci.yml' -Repository 'o/r' -WhatIf
        $workflows | Disable-GitHubWorkflow -WhatIf
    }

    # Assert
    $expected = @(
        'What if: Performing the operation "Disable workflow" on target "o/r workflow ci.yml".'
        'What if: Performing the operation "Disable workflow" on target "a/b workflow 1".'
        'What if: Performing the operation "Disable workflow" on target "workflow b.yml".'
    )
    Assert-Equal -Expected $expected -Actual $whatIf.Messages `
        -Message '-WhatIf names each workflow, in its repository when one is known'
    Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count `
        -Message 'and gh is never called'
    Assert-Equal -Expected 0 -Actual $whatIf.Output.Count -Message 'and nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a repository URL that carries a token, and the same repository
# written other ways
$fake = New-FakeGitHubCli
try {
    $repositories = @(
        'https://user:SENTINEL@github.com/o/r'
        'https://www.github.com/o/r.git'
        [PSCustomObject]@{ Url = 'https://user:SENTINEL@github.com/o/r' }
    )

    # Act
    $whatIf = Get-WhatIfOutput -ScriptBlock {
        foreach ($repository in $repositories) {
            Disable-GitHubWorkflow -Workflow 'ci.yml' -Repository $repository -WhatIf
        }
    }

    # Assert
    $line = 'What if: Performing the operation "Disable workflow" on target "o/r workflow ci.yml".'
    Assert-Equal -Expected @($line, $line, $line) -Actual $whatIf.Messages `
        -Message '-WhatIf names the repository as OWNER/REPO however it was given'
    Assert-Equal -Expected @() -Actual @($whatIf.Messages -match 'SENTINEL') `
        -Message 'and never shows the token'
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
        [PSCustomObject]@{ Id = 1; Repository = 'other/repo' } | Disable-GitHubWorkflow -Repository 'o/r' -WhatIf
    } -MessageLike 'Workflow 1 is in other/repo, but -Repository names o/r: give one or the other.' `
        -Message 'With -WhatIf, a -Repository naming another repository still throws'

    # Act
    Disable-GitHubWorkflow -Workflow 'ci.yml' -Repository 'o/r' -Confirm:$false
    $call = @(Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'disable', '--repo', 'o/r', '--', 'ci.yml') -Actual $call.Arguments `
        -Message '-Confirm:$false runs the change, and adds nothing to gh''s arguments'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
