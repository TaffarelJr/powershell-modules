#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($required in 'TaffarelJr.GitHub.Core', 'TaffarelJr.ProcessInvocation') {
    $loaded = Get-Module -Name $required
    if (-not $loaded) {
        throw "$required must be loaded before TaffarelJr.GitHub.PullRequests."
    }

    Import-Module -ModuleInfo $loaded -ErrorAction Stop
}

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Add-GitHubPullRequestComment'
    'Close-GitHubPullRequest'
    'Get-GitHubPullRequest'
    'Get-GitHubPullRequestCheck'
    'Get-GitHubPullRequestDiff'
    'Get-GitHubPullRequestStatus'
    'Lock-GitHubPullRequest'
    'Merge-GitHubPullRequest'
    'New-GitHubPullRequest'
    'Open-GitHubPullRequest'
    'Set-GitHubPullRequest'
    'Submit-GitHubPullRequestReview'
    'Switch-GitHubPullRequest'
    'Unlock-GitHubPullRequest'
    'Update-GitHubPullRequestBranch'
)
