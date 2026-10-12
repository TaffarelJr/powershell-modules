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
# Act - an open issue from a real repository
$issues = @(Find-GitHubIssue -Repository 'cli/cli' -State open -Limit 1)

# Assert
Assert-Equal -Expected 1 -Actual $issues.Count -Message 'The live search honors -Limit'
Assert-That -Condition (($issues | ForEach-Object Number) -gt 0) -Message 'A result carries its number'
Assert-Equal -Expected 'open' -Actual ($issues | ForEach-Object State) -Message 'and the state asked for'
Assert-Equal -Expected $null -Actual ($issues | ForEach-Object ClosedAt) -Message 'An open issue''s ClosedAt is $null'
Assert-Equal -Expected $false -Actual ($issues | ForEach-Object IsPullRequest) `
    -Message 'and it is an issue, not a pull request'

#───────────────────────────────────────────────────────────────────────────────
# Act - closed locked issues, which stay locked, then the same query asking for unlocked ones
$locked = @(Find-GitHubIssue -Repository 'cli/cli' -State closed -Query 'is:locked' -Limit 1)
$contradiction = @(Find-GitHubIssue -Repository 'cli/cli' -State closed -Query 'is:locked' -Locked:$false -Limit 1)

# Assert
Assert-Equal -Expected 1 -Actual $locked.Count `
    -Message 'The repository has a closed locked issue, the baseline the next check needs'
Assert-Equal -Expected 0 -Actual $contradiction.Count `
    -Message 'and -Locked:$false excludes it, so the false form reaches gh as a filter'

exit (Complete-TestRun)
