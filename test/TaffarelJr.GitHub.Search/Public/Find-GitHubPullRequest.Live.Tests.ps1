#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Search/TaffarelJr.GitHub.Search.psd1') -Force
. (Join-Path $PSScriptRoot '..' '..' 'GitHubTestHelper.ps1')

if (-not (Test-LiveGitHub)) {
    exit (Skip-TestRun -Reason 'gh has no working login here')
}

#───────────────────────────────────────────────────────────────────────────────
# Act - a merged pull request from a real repository
$merged = @(Find-GitHubPullRequest -Repository 'cli/cli' -Merged -Limit 1)

# Assert
Assert-Equal -Expected 1 -Actual $merged.Count -Message 'The live search honors -Limit'
Assert-That -Condition (@($merged | ForEach-Object { $_.PSObject.Properties.Name }) -contains 'IsDraft') `
    -Message 'A result carries IsDraft, as gh accepted the whole field list'
Assert-That -Condition (($merged | ForEach-Object ClosedAt) -is [datetime]) `
    -Message 'and a merged pull request has a ClosedAt'

#───────────────────────────────────────────────────────────────────────────────
# Act - closed pull requests of each kind, which stay so, then the same query with the switch passed as false
$locked = @(Find-GitHubPullRequest -Repository 'cli/cli' -State closed -Query 'is:locked' -Limit 1)
$notLocked = @(Find-GitHubPullRequest -Repository 'cli/cli' -State closed -Query 'is:locked' -Locked:$false -Limit 1)
$draft = @(Find-GitHubPullRequest -Repository 'cli/cli' -State closed -Query 'is:draft' -Limit 1)
$notDraft = @(Find-GitHubPullRequest -Repository 'cli/cli' -State closed -Query 'is:draft' -Draft:$false -Limit 1)
$notMerged = @(Find-GitHubPullRequest -Repository 'cli/cli' -Query 'is:merged' -Merged:$false -Limit 1)

# Assert
Assert-Equal -Expected 1 -Actual $locked.Count `
    -Message 'The repository has a closed locked pull request, the baseline the next check needs'
Assert-Equal -Expected 0 -Actual $notLocked.Count `
    -Message 'and -Locked:$false excludes it, though gh ignores --locked=false for pull requests'
Assert-Equal -Expected 1 -Actual $draft.Count `
    -Message 'The repository has a closed draft pull request, the baseline the next check needs'
Assert-Equal -Expected 0 -Actual $notDraft.Count -Message 'and -Draft:$false excludes it'
Assert-Equal -Expected 0 -Actual $notMerged.Count -Message '-Merged:$false excludes the merged ones'

exit (Complete-TestRun)
