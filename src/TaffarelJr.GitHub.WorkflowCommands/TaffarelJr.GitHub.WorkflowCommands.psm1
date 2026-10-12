#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Add-GitHubActionsPath'
    'Add-GitHubActionsStepSummary'
    'Enter-GitHubActionsLogGroup'
    'Exit-GitHubActionsLogGroup'
    'Get-GitHubActionsState'
    'Hide-GitHubActionsValue'
    'Save-GitHubActionsState'
    'Set-GitHubActionsEnvironmentVariable'
    'Set-GitHubActionsOutput'
    'Write-GitHubActionsDebug'
    'Write-GitHubActionsError'
    'Write-GitHubActionsNotice'
    'Write-GitHubActionsWarning'
)
