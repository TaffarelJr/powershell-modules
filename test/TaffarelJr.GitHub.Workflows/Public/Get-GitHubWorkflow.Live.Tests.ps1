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
# Act - the real gh against a public repository with several workflows
$workflows = @(Get-GitHubWorkflow -Limit 2 -Repository 'cli/cli')

# Assert
Assert-That -Condition ($workflows.Count -gt 0) -Message 'The live repository has workflows'
Assert-That -Condition ($workflows[0].Id -is [long]) `
    -Message 'A workflow carries its numeric Id, which the other functions read it by'
Assert-That -Condition ($workflows[0].Path -like '.github/workflows/*') -Message 'and its file path'

exit (Complete-TestRun)
