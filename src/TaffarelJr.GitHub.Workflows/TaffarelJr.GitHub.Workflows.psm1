#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot/Public -Filter *.ps1) {
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
)