#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

$originalState = $env:GITHUB_STATE
$tempDir = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $env:GITHUB_STATE = Join-Path $tempDir 'state.txt'

    # Act
    Save-GitHubActionsState -Name 'containerId' -Value 'abc123'
    $text = [File]::ReadAllText($env:GITHUB_STATE)

    # Assert
    Assert-That -Condition ($text -match '^containerId<<ghadelimiter_[0-9a-f-]+\r?\nabc123\r?\nghadelimiter_[0-9a-f-]+\r?\n$') `
        -Message 'The state is appended to the state file in the heredoc form'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - not running inside a step
    Remove-Item Env:\GITHUB_STATE -ErrorAction SilentlyContinue

    # Act / Assert
    Assert-Throws -ScriptBlock { Save-GitHubActionsState -Name 'x' -Value 'y' } -Message 'With GITHUB_STATE unset, Save-GitHubActionsState throws'
}
finally {
    if ($null -eq $originalState) { Remove-Item Env:\GITHUB_STATE -ErrorAction SilentlyContinue } else { $env:GITHUB_STATE = $originalState }
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
