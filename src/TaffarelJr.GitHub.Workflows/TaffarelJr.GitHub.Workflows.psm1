#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Enough consecutive unreadable polls to call it, shared by
# Wait-GitHubWorkflowRun and Wait-GitHubWorkflowRunStart: enough to ride
# out one blip, short enough that a genuinely broken gh call still ends
# the wait instead of running out the clock on every remaining poll.
$script:MaxUnreadablePolls = 3

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
        'Wait-GitHubWorkflowRunStart'
)