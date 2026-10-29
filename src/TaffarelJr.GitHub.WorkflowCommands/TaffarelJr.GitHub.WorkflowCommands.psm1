#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($required in 'TaffarelJr.ProcessInvocation') {
    $loaded = Get-Module -Name $required
    if (-not $loaded) {
        throw "$required must be loaded before TaffarelJr.GitHub.WorkflowCommands."
    }

    Import-Module -ModuleInfo $loaded -ErrorAction Stop
}

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
    'Invoke-GitHubActionsLogGroup'
    'Save-GitHubActionsState'
    'Set-GitHubActionsEnvironmentVariable'
    'Set-GitHubActionsOutput'
    'Write-GitHubActionsDebug'
    'Write-GitHubActionsError'
    'Write-GitHubActionsNotice'
    'Write-GitHubActionsWarning'
)
