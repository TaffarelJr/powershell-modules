#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($required in 'TaffarelJr.GitHub.Core', 'TaffarelJr.ProcessInvocation') {
    $loaded = Get-Module -Name $required
    if (-not $loaded) {
        throw "$required must be loaded before TaffarelJr.GitHub.Account."
    }

    Import-Module -ModuleInfo $loaded -ErrorAction Stop
}

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Clear-GitHubConfigCache'
    'Connect-GitHubAccount'
    'Disconnect-GitHubAccount'
    'Get-GitHubAuthStatus'
    'Get-GitHubConfig'
    'Get-GitHubOrganization'
    'Get-GitHubToken'
    'Register-GitHubCredentialHelper'
    'Set-GitHubConfig'
    'Switch-GitHubAccount'
)
