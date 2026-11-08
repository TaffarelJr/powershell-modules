#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($required in 'TaffarelJr.GitHub.Core', 'TaffarelJr.ProcessInvocation') {
    $loaded = Get-Module -Name $required
    if (-not $loaded) {
        throw "$required must be loaded before TaffarelJr.GitHub.Repositories."
    }

    Import-Module -ModuleInfo $loaded -ErrorAction Stop
}

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
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
