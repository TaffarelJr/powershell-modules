#Requires -Version 7.0
using namespace System.IO

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/TaffarelJr.GitHub.WorkflowCommands.psd1') -Force

$originalSummary = $env:GITHUB_STEP_SUMMARY
$tempDir = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    #───────────────────────────────────────────────────────────────────────────
    # Arrange
    $env:GITHUB_STEP_SUMMARY = Join-Path $tempDir 'summary.md'

    # Act
    Add-GitHubActionsStepSummary -Markdown '## Results'
    Add-GitHubActionsStepSummary -Markdown '- all green'
    $text = [File]::ReadAllText($env:GITHUB_STEP_SUMMARY)

    # Assert
    Assert-Equal -Expected "## Results`n- all green`n" -Actual $text -Message 'Each call appends its Markdown, exactly as given, with one trailing newline'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - content that would push the summary past the 1 MiB limit
    $env:GITHUB_STEP_SUMMARY = Join-Path $tempDir 'huge.md'
    [File]::WriteAllText($env:GITHUB_STEP_SUMMARY, ('x' * (1024 * 1024)))

    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitHubActionsStepSummary -Markdown 'one more byte' } -Message 'Writing past the 1 MiB limit throws instead of truncating silently'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange - not running inside a step
    Remove-Item Env:\GITHUB_STEP_SUMMARY -ErrorAction SilentlyContinue

    # Act / Assert
    Assert-Throws -ScriptBlock { Add-GitHubActionsStepSummary -Markdown 'x' } -Message 'With GITHUB_STEP_SUMMARY unset, Add-GitHubActionsStepSummary throws'
}
finally {
    if ($null -eq $originalSummary) { Remove-Item Env:\GITHUB_STEP_SUMMARY -ErrorAction SilentlyContinue } else { $env:GITHUB_STEP_SUMMARY = $originalSummary }
    Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Complete-TestRun)
