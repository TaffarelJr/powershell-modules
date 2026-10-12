#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Public -Filter *.ps1) {
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