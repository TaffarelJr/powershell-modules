#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Workflows/TaffarelJr.GitHub.Workflows.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the real gh against a public repository that runs Actions constantly
$runs = Get-GitHubWorkflowRun -List -Limit 1 -Repository 'cli/cli'

# Assert
Assert-Equal -Expected 1 -Actual $runs.Count -Message 'The live listing honors -Limit'
Assert-That -Condition ($runs[0].DatabaseId -gt 0) -Message 'A listed run carries its database id'
Assert-That -Condition (-not [string]::IsNullOrEmpty($runs[0].HeadSha)) -Message 'A listed run carries its commit'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same run with its jobs
$run = Get-GitHubWorkflowRun -RunId $runs[0].DatabaseId -Repository 'cli/cli'

# Assert
Assert-Equal -Expected $runs[0].DatabaseId -Actual $run.DatabaseId -Message 'A run described by id is the one asked'
Assert-That -Condition ($run.Jobs -is [array]) -Message 'The described run carries its jobs as an array'

#───────────────────────────────────────────────────────────────────────────────
# Act - the listed runs piped back in, as a real listing returns them
$both = @(Get-GitHubWorkflowRun -List -Limit 2 -Repository 'cli/cli')
$described = @($both | Get-GitHubWorkflowRun -Repository 'cli/cli')

# Assert
Assert-Equal -Expected @($both.ForEach('DatabaseId')) -Actual @($described.ForEach('DatabaseId')) `
    -Message 'Each listed run piped back in is described by its DatabaseId'

exit (Complete-TestRun)
