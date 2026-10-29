#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')
. (Join-Path $PSScriptRoot '..' 'PreferenceTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - each changing function, called from a function that was given -WhatIf
$changes = @(
    @{ Call = { Disable-GitHubWorkflow -Workflow 'ci.yml' -Repository 'o/r' }; Name = 'Disable-GitHubWorkflow' }
    @{ Call = { Enable-GitHubWorkflow -Workflow 'ci.yml' -Repository 'o/r' }; Name = 'Enable-GitHubWorkflow' }
    @{ Call = { Remove-GitHubCache -Id 7 -Repository 'o/r' }; Name = 'Remove-GitHubCache' }
    @{ Call = { Remove-GitHubWorkflowRun -RunId 5 -Repository 'o/r' }; Name = 'Remove-GitHubWorkflowRun' }
    @{ Call = { Restart-GitHubWorkflowRun -RunId 5 -Repository 'o/r' }; Name = 'Restart-GitHubWorkflowRun' }
    @{
        Call = { Save-GitHubWorkflowRunArtifact -RunId 5 -Destination 'artifacts' -Repository 'o/r' }
        Name = 'Save-GitHubWorkflowRunArtifact'
    }
    @{ Call = { Start-GitHubWorkflow -Workflow 'ci.yml' -Repository 'o/r' }; Name = 'Start-GitHubWorkflow' }
    @{ Call = { Stop-GitHubWorkflowRun -RunId 5 -Repository 'o/r' }; Name = 'Stop-GitHubWorkflowRun' }
)
foreach ($change in $changes) {
    $fake = New-FakeGitHubCli
    try {
        # Act
        $call = $change.Call
        $result = Get-WhatIfOutput -ScriptBlock { Invoke-WhatIfCaller -Call $call -WhatIf }

        # Assert
        Assert-Equal -Expected 1 -Actual $result.Messages.Count `
            -Message "$($change.Name) called from a function given -WhatIf says what it would do"
        Assert-Equal -Expected 0 -Actual @(Get-FakeGitHubCall -Fixture $fake).Count -Message 'and does not call gh'
    }
    finally {
        Remove-FakeGitHubCli -Fixture $fake
    }
}

exit (Complete-TestRun)
