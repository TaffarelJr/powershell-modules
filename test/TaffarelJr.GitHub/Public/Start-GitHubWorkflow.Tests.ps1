#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a dispatch with inputs on a ref
$fake = New-FakeGitHubCli -Output @('✓ Created workflow_dispatch event for draft-release.yml at main', 'https://github.com/o/r/actions/runs/9')
try {
    # Act
    $url = Start-GitHubWorkflow -Workflow 'draft-release.yml' -Ref 'main' -Inputs @{ version = '1.2.3'; dry_run = 'true' } -Repository 'o/r'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'run', 'draft-release.yml', '--ref', 'main', '--raw-field', 'dry_run=true', '--raw-field', 'version=1.2.3', '--repo', 'o/r') -Actual $call.Arguments -Message 'Inputs become sorted --raw-field pairs behind the workflow and ref'
    Assert-Equal -Expected 'https://github.com/o/r/actions/runs/9' -Actual $url -Message 'The run URL is picked out of gh''s output'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - no inputs, and gh reports no URL
$fake = New-FakeGitHubCli -Output @('✓ Created workflow_dispatch event for ci.yml at main')
try {
    # Act
    $url = Start-GitHubWorkflow -Workflow 'ci.yml'
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'run', 'ci.yml') -Actual $call.Arguments -Message 'Without options, only the workflow is named'
    Assert-That -Condition ($null -eq $url) -Message 'No URL in gh''s output means nothing is returned'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a workflow piped in by property, as Get-GitHubWorkflow returns it
$fake = New-FakeGitHubCli
try {
    # Act
    [PSCustomObject]@{ Id = 42; Name = 'CI'; Path = '.github/workflows/ci.yml' } | Start-GitHubWorkflow | Out-Null
    $call = (Get-FakeGitHubCall -Fixture $fake)[0]

    # Assert
    Assert-Equal -Expected @('workflow', 'run', '.github/workflows/ci.yml') -Actual $call.Arguments -Message 'The Path property binds from the pipeline'
}
finally {
    Remove-FakeGitHubCli -Fixture $fake
}

exit (Complete-TestRun)
