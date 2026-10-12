#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Public -Filter *.ps1) {
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