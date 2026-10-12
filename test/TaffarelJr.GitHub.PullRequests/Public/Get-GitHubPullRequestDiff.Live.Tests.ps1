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

# The newest merged pull request can be an empty one, with no diff to read.
$recent = @(Get-GitHubPullRequest -List -State merged -Limit 20 -Property 'number,changedFiles' -Repository 'cli/cli')
$merged = $recent | Where-Object { $_.ChangedFiles -gt 0 } | Select-Object -First 1

#───────────────────────────────────────────────────────────────────────────────
# Act - the real gh lists a merged pull request's changed files
$names = @(Get-GitHubPullRequestDiff -PullRequest $merged.Number -NameOnly -Repository 'cli/cli')

# Assert
Assert-Equal -Expected $merged.ChangedFiles -Actual $names.Count -Message 'Every changed file is named, one per line'

#───────────────────────────────────────────────────────────────────────────────
# Act - the whole diff, with color forced on in the environment
$saved = $env:CLICOLOR_FORCE
$env:CLICOLOR_FORCE = '1'
try {
    $diff = @(Get-GitHubPullRequestDiff -PullRequest $merged.Number -Repository 'cli/cli')
}
finally {
    $env:CLICOLOR_FORCE = $saved
}

# Assert
Assert-That -Condition ($diff[0] -clike 'diff --git a/*') -Message 'The diff starts with its first file''s header'
Assert-Equal -Expected @() -Actual @($diff | Where-Object { $_.Contains([char]27) }) `
    -Message 'and holds no color codes, even with color forced'

exit (Complete-TestRun)
