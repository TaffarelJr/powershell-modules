#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
. (Join-Path $repoRoot 'src/TaffarelJr.GitHub.WorkflowCommands/Private/Test-GitHubActionsRunnerVariable.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - names in the runner's own casing
$cases = @(
    @{ Name = 'GITHUB_SHA'; Expected = $true; Message = 'A github context key the runner exposes is its own' }
    @{ Name = 'GITHUB_OUTPUT'; Expected = $true; Message = 'as is a command file it names' }
    @{ Name = 'GITHUB_STEP_SUMMARY'; Expected = $true; Message = 'as is a key with an underscore of its own' }
    @{ Name = 'GITHUB_ACTIONS'; Expected = $true; Message = 'as is GITHUB_ACTIONS, set for every process' }
    @{ Name = 'RUNNER_TEMP'; Expected = $true; Message = 'A runner context key is the runner''s own' }
    @{ Name = 'RUNNER_TOOL_CACHE'; Expected = $true; Message = 'as is one with an underscore of its own' }
    @{ Name = 'RUNNER_DEBUG'; Expected = $true; Message = 'as is RUNNER_DEBUG, set when debug logging is on' }
    @{ Name = 'GITHUB_TOKEN'; Expected = $false; Message = 'GITHUB_TOKEN is not exposed, so it reaches later steps' }
    @{ Name = 'GITHUB_PAT'; Expected = $false; Message = 'nor is any other GITHUB_ name off the list' }
    @{ Name = 'RUNNER_FOO'; Expected = $false; Message = 'nor a RUNNER_ name off the list' }
    @{ Name = 'CI'; Expected = $false; Message = 'nor CI, which the runner sets only when nothing else has' }
)

# Act / Assert
foreach ($case in $cases) {
    Assert-Equal -Expected $case.Expected -Actual (Test-GitHubActionsRunnerVariable -Name $case.Name) `
        -Message $case.Message
}

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - another casing
Assert-Equal -Expected $true -Actual (Test-GitHubActionsRunnerVariable -Name 'github_sha' -IgnoreCase) `
    -Message 'Where names ignore case, as on Windows, any casing is the runner''s'
Assert-Equal -Expected $false -Actual (Test-GitHubActionsRunnerVariable -Name 'github_sha') `
    -Message 'where they keep it, another casing is another variable'

exit (Complete-TestRun)
