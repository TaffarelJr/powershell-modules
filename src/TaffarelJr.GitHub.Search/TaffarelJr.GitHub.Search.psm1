#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
        'Find-GitHubCode'
        'Find-GitHubCommit'
        'Find-GitHubIssue'
        'Find-GitHubPullRequest'
        'Find-GitHubRepository'
)