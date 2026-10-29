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

$buckets = @('pass', 'fail', 'pending', 'skipping', 'cancel')
$merged = Get-GitHubPullRequest -List -State merged -Limit 1 -Property 'number' -Repository 'cli/cli'

#───────────────────────────────────────────────────────────────────────────────
# Act - the real gh reads a merged pull request's checks, all finished
$checks = @(Get-GitHubPullRequestCheck -PullRequest $merged.Number -Repository 'cli/cli')

# Assert
Assert-That -Condition ($checks.Count -gt 0) `
    -Message 'A merged pull request of cli/cli has checks, and gh prints them with --json'
Assert-Equal -Expected @() -Actual @($checks | Where-Object { $_.Bucket -notin $buckets }) `
    -Message 'Every check carries one of the Buckets gh documents'
Assert-Equal -Expected @() -Actual @($checks | Where-Object { -not $_.Name }) -Message 'and its Name'

#───────────────────────────────────────────────────────────────────────────────
# Act - only the required ones, which may be none at all
$required = @(Get-GitHubPullRequestCheck -PullRequest $merged.Number -Required -Repository 'cli/cli')

# Assert
Assert-Equal -Expected @() -Actual @($required | Where-Object { $_.Bucket -notin $buckets }) `
    -Message 'Required checks, or none, come back without a throw'

#───────────────────────────────────────────────────────────────────────────────
# Act - waiting on checks that are already finished
$waited = @(Get-GitHubPullRequestCheck -PullRequest $merged.Number -Wait -TimeoutSeconds 60 -Repository 'cli/cli')

# Assert
Assert-Equal -Expected $checks.Count -Actual $waited.Count -Message '-Wait returns at once when nothing is pending'

exit (Complete-TestRun)
