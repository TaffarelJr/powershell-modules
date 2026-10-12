#Requires -Version 7.4

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($required in 'TaffarelJr.GitHub.Core', 'TaffarelJr.ProcessInvocation') {
    $loaded = Get-Module -Name $required
    if (-not $loaded) {
        throw "$required must be loaded before TaffarelJr.GitHub.Workflows."
    }

    Import-Module -ModuleInfo $loaded -ErrorAction Stop
}

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Private, $PSScriptRoot/Public -Filter *.ps1) {
    . $file.FullName
}

Export-ModuleMember -Function @(
    'Disable-GitHubWorkflow'
    'Enable-GitHubWorkflow'
    'Get-GitHubCache'
    'Get-GitHubWorkflow'
    'Get-GitHubWorkflowRun'
    'Get-GitHubWorkflowRunLog'
    'Remove-GitHubCache'
    'Remove-GitHubWorkflowRun'
    'Restart-GitHubWorkflowRun'
    'Save-GitHubWorkflowRunArtifact'
    'Start-GitHubWorkflow'
    'Stop-GitHubWorkflowRun'
    'Wait-GitHubWorkflowRun'
    'Wait-GitHubWorkflowRunStart'
)
