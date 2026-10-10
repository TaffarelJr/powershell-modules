#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange
$fake = New-FakeGitHubCli
try {
    # Act
    Enable-GitHubWorkflow -Workflow 'ci.yml' -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'enable', 'ci.yml', '--repo', 'o/r') -Actual $call.Arguments -Message 'The workflow is positional and the repository goes through --repo'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - workflows piped in as Get-GitHubWorkflow returns them
$fake = New-FakeGitHubCli
try {
    # Act
    @(
        [PSCustomObject]@{ Id = 1; Name = 'A'; Path = '.github/workflows/a.yml' }
        [PSCustomObject]@{ Id = 2; Name = 'B'; Path = '.github/workflows/b.yml' }
    ) | Enable-GitHubWorkflow
    $calls = Get-FakeGitHubCall -Fixture $fake

    # Assert
    Assert-Equal -Expected 2 -Actual $calls.Count -Message 'Each piped workflow is enabled in its own call'
    Assert-Equal -Expected @('workflow', 'enable', '.github/workflows/b.yml') -Actual $calls[1].Arguments -Message 'The Path property binds from the pipeline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
