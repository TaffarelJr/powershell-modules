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
# Act - the real gh against a public repository, every state so there is
# always something to list
$pullRequests = Get-GitHubPullRequest -List -State all -Limit 2 -Repository 'cli/cli'

# Assert
Assert-Equal -Expected 2 -Actual $pullRequests.Count -Message 'The live listing honors -Limit'
Assert-That -Condition ($pullRequests[0].Number -gt 0) -Message 'A listed pull request carries its number'
Assert-That -Condition (-not [string]::IsNullOrEmpty($pullRequests[0].Author.Login)) -Message 'A nested field gh really returns is populated'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same pull request on its own
$single = Get-GitHubPullRequest -PullRequest $pullRequests[0].Number -Repository 'cli/cli'

# Assert
Assert-Equal -Expected $pullRequests[0].Number -Actual $single.Number -Message 'A pull request described by number is the one asked for'
Assert-That -Condition ($single.PSObject.Properties.Name -contains 'StatusCheckRollup') -Message 'A requested field is present as a PascalCase property'

exit (Complete-TestRun)
