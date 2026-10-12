#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
        'Add-GitHubReleaseAsset'
        'Get-GitHubRelease'
        'New-GitHubRelease'
        'Remove-GitHubRelease'
        'Remove-GitHubReleaseAsset'
        'Save-GitHubReleaseAsset'
        'Set-GitHubRelease'
)