#Requires -Version 7.4
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.Core/TaffarelJr.GitHub.Core.psd1') -Force
$module = Import-Module (Join-Path $repoRoot 'src/TaffarelJr.GitHub.PullRequests/TaffarelJr.GitHub.PullRequests.psd1') `
    -Force `
    -PassThru

$resolve = {
    param($Bound, $Repository, [switch]$NoBranch, [switch]$AllowCurrent)
    $target = @{
        BoundParameters = $Bound
        Repository      = $Repository
        NoBranch        = $NoBranch
        AllowCurrent    = $AllowCurrent
    }
    Resolve-GitHubPullRequestTarget @target
}

#───────────────────────────────────────────────────────────────────────────────
# Act - no pull request given
$target = & $module $resolve @{}

# Assert
Assert-Equal -Expected ([string[]]@()) -Actual $target.Arguments `
    -Message 'No pull request gives no operand, for gh to use the current branch''s'
Assert-Equal -Expected "the current branch's pull request" -Actual $target.Name `
    -Message 'and names it as the current branch''s'

#───────────────────────────────────────────────────────────────────────────────
# Act - a pull request given
$target = & $module $resolve @{ PullRequest = '#7' } 'o/r'

# Assert
Assert-Equal -Expected ([string[]]@('7')) -Actual $target.Arguments `
    -Message 'A given pull request is resolved to its operand'
Assert-Equal -Expected 'pull request 7' -Actual $target.Name -Message 'and named by it'

#───────────────────────────────────────────────────────────────────────────────
# Act - a URL, for a subcommand that takes no branch
$target = & $module $resolve @{ PullRequest = 'https://github.com/o/r/pull/7' } -NoBranch

# Assert
Assert-Equal -Expected ([string[]]@('https://github.com/o/r/pull/7')) -Actual $target.Arguments `
    -Message 'A URL passes -NoBranch'

#───────────────────────────────────────────────────────────────────────────────
# Act - a repository alone, for a subcommand that still looks for the
# current branch's pull request then
$target = & $module $resolve @{} 'o/r' -AllowCurrent

# Assert
Assert-Equal -Expected ([string[]]@()) -Actual $target.Arguments `
    -Message '-AllowCurrent lets -Repository go without a pull request'

#───────────────────────────────────────────────────────────────────────────────
# Act / Assert - the refusals
Assert-Throws -ScriptBlock {
    & $module $resolve @{ PullRequest = $null }
} -MessageLike "A pull request was given, but it is `$null - leave it out to use the current branch's pull request." `
    -Message 'A pull request given as $null throws'
Assert-Throws -ScriptBlock {
    & $module $resolve @{} 'o/r'
} -MessageLike '-Repository o/r was given without a pull request, and gh needs one named along with --repo.*' `
    -Message 'A repository alone throws'
Assert-Throws -ScriptBlock {
    & $module $resolve @{ PullRequest = 'feature' } -NoBranch
} -MessageLike "'feature' is not a pull request: give its number or URL, as gh takes no branch name here." `
    -Message 'A branch name throws with -NoBranch'
Assert-Throws -ScriptBlock {
    & $module $resolve @{ PullRequest = '12abc' } -NoBranch
} -MessageLike "'12abc' is not a pull request: give its number or URL*" `
    -Message 'and so does a branch name that starts with digits'
Assert-Throws -ScriptBlock {
    & $module $resolve @{ PullRequest = 'https://github.com/a/b/pull/7'; Repository = 'a/b' } 'c/d'
} -MessageLike "'https://github.com/a/b/pull/7' is in a/b, but -Repository names c/d: give one or the other." `
    -Message 'The URL is checked against the -Repository given, not the raw bound value'

exit (Complete-TestRun)
