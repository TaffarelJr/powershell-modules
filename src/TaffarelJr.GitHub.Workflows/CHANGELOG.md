# Changelog

## 0.1.0

Initial release: `Disable-GitHubWorkflow`, `Enable-GitHubWorkflow`, `Get-GitHubCache`, `Get-GitHubWorkflow`, `Get-GitHubWorkflowRun`, `Get-GitHubWorkflowRunLog`, `Remove-GitHubCache`, `Remove-GitHubWorkflowRun`, `Restart-GitHubWorkflowRun`, `Save-GitHubWorkflowRunArtifact`, `Start-GitHubWorkflow`, `Stop-GitHubWorkflowRun`, `Wait-GitHubWorkflowRun`, `Wait-GitHubWorkflowRunStart`.

`Wait-GitHubWorkflowRun` polls gh directly instead of delegating to `gh run watch`, and takes `-TimeoutSeconds`/`-PollSeconds` in place of `-Interval`.