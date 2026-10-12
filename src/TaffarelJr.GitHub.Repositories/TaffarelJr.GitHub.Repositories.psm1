#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
        'Add-GitHubDeployKey'
        'Copy-GitHubLabel'
        'Get-GitHubDefaultRepository'
        'Get-GitHubDeployKey'
        'Get-GitHubLabel'
        'Get-GitHubRepository'
        'Get-GitHubRuleset'
        'Get-GitHubRulesetCheck'
        'Get-GitHubSecret'
        'Get-GitHubVariable'
        'New-GitHubFork'
        'New-GitHubLabel'
        'New-GitHubRepository'
        'Remove-GitHubDeployKey'
        'Remove-GitHubLabel'
        'Remove-GitHubRepository'
        'Remove-GitHubSecret'
        'Remove-GitHubVariable'
        'Rename-GitHubRepository'
        'Set-GitHubDefaultRepository'
        'Set-GitHubLabel'
        'Set-GitHubRepository'
        'Set-GitHubSecret'
        'Set-GitHubVariable'
        'Sync-GitHubRepository'
)