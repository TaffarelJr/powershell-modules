#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
        'Add-GitHubIssueComment'
        'Close-GitHubIssue'
        'Get-GitHubIssue'
        'Get-GitHubIssueStatus'
        'Lock-GitHubIssue'
        'Move-GitHubIssue'
        'New-GitHubIssue'
        'Open-GitHubIssue'
        'Remove-GitHubIssue'
        'Set-GitHubIssue'
        'Unlock-GitHubIssue'
)