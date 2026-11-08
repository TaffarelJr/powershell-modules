#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

#───────────────────────────────────────────────────────────────────────────────
# Act - the real gh against a public repository, every state so there is
# always something to list
$pullRequests = Get-GitHubPullRequest -List -State all -Limit 2 -Repository 'cli/cli'

# Assert
Assert-Equal -Expected 2 -Actual $pullRequests.Count -Message 'The live listing honors -Limit'
Assert-That -Condition ($pullRequests[0].Number -gt 0) -Message 'A listed pull request carries its number'
Assert-That -Condition (-not [string]::IsNullOrEmpty($pullRequests[0].Author.Login)) `
    -Message 'A nested field gh really returns is populated'

#───────────────────────────────────────────────────────────────────────────────
# Act - the same pull request on its own
$single = Get-GitHubPullRequest -PullRequest $pullRequests[0].Number -Repository 'cli/cli'

# Assert
Assert-Equal -Expected $pullRequests[0].Number -Actual $single.Number `
    -Message 'A pull request described by number is the one asked for'
Assert-That -Condition ($single.PSObject.Properties.Name -contains 'StatusCheckRollup') `
    -Message 'A requested field is present as a PascalCase property'

#───────────────────────────────────────────────────────────────────────────────
# Act - the listed pull requests piped back in, with no -Repository
$piped = @($pullRequests | Get-GitHubPullRequest)

# Assert
Assert-Equal -Expected @($pullRequests.ForEach('Number')) -Actual @($piped.ForEach('Number')) `
    -Message 'A listed pull request piped back in is found by its URL, in the repository it came from'

exit (Complete-TestRun)
