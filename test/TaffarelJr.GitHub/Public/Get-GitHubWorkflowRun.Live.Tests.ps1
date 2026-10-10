#Requires -Version 7.0
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub/TaffarelJr.GitHub.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    Write-Host 'skipped - gh has no working login here'
    exit (Complete-TestRun)
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
$run = Get-GitHubWorkflowRun -Id $runs[0].DatabaseId -Repository 'cli/cli'

# Assert
Assert-Equal -Expected $runs[0].DatabaseId -Actual $run.DatabaseId -Message 'A run described by id is the one asked for'
Assert-That -Condition ($run.Jobs -is [array]) -Message 'The described run carries its jobs as an array'

#───────────────────────────────────────────────────────────────────────────────
# Act - the repository's workflows
$workflows = Get-GitHubWorkflow -Limit 2 -Repository 'cli/cli'

# Assert
Assert-That -Condition ($workflows.Count -gt 0) -Message 'The live repository has workflows'
Assert-That -Condition ($workflows[0].Path -like '.github/workflows/*') -Message 'A workflow carries its file path'

exit (Complete-TestRun)
