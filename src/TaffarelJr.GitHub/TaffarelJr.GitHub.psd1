@{
    RootModule        = 'TaffarelJr.GitHub.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '76a81fd0-822c-4c83-bbe8-885e6a16f8cc'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Wraps the GitHub CLI (gh) for everyday scripting: the REST and GraphQL API, authentication, repositories, pull requests, releases, workflow runs and workflows, labels, secrets, and variables - every call going through one private process-invocation core, and every JSON result coming back as objects.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'Add-GitHubDeployKey'
        'Add-GitHubPullRequestComment'
        'Add-GitHubReleaseAsset'
        'Close-GitHubPullRequest'
        'Connect-GitHubAccount'
        'Copy-GitHubLabel'
        'Disable-GitHubWorkflow'
        'Disconnect-GitHubAccount'
        'Enable-GitHubWorkflow'
        'Get-GitHubAuthStatus'
        'Get-GitHubDefaultRepository'
        'Get-GitHubDeployKey'
        'Get-GitHubLabel'
        'Get-GitHubPullRequest'
        'Get-GitHubPullRequestCheck'
        'Get-GitHubPullRequestDiff'
        'Get-GitHubPullRequestStatus'
        'Get-GitHubRelease'
        'Get-GitHubRepository'
        'Get-GitHubSecret'
        'Get-GitHubToken'
        'Get-GitHubVariable'
        'Get-GitHubWorkflow'
        'Get-GitHubWorkflowRun'
        'Get-GitHubWorkflowRunLog'
        'Invoke-GitHubApi'
        'Lock-GitHubPullRequest'
        'Merge-GitHubPullRequest'
        'New-GitHubFork'
        'New-GitHubLabel'
        'New-GitHubPullRequest'
        'New-GitHubRelease'
        'New-GitHubRepository'
        'Open-GitHubPullRequest'
        'Register-GitHubCredentialHelper'
        'Remove-GitHubDeployKey'
        'Remove-GitHubLabel'
        'Remove-GitHubRelease'
        'Remove-GitHubReleaseAsset'
        'Remove-GitHubRepository'
        'Remove-GitHubSecret'
        'Remove-GitHubVariable'
        'Remove-GitHubWorkflowRun'
        'Rename-GitHubRepository'
        'Restart-GitHubWorkflowRun'
        'Save-GitHubReleaseAsset'
        'Save-GitHubWorkflowRunArtifact'
        'Set-GitHubDefaultRepository'
        'Set-GitHubLabel'
        'Set-GitHubPullRequest'
        'Set-GitHubRelease'
        'Set-GitHubRepository'
        'Set-GitHubSecret'
        'Set-GitHubVariable'
        'Start-GitHubWorkflow'
        'Stop-GitHubWorkflowRun'
        'Submit-GitHubPullRequestReview'
        'Switch-GitHubAccount'
        'Switch-GitHubPullRequest'
        'Sync-GitHubRepository'
        'Test-GitHubApi'
        'Unlock-GitHubPullRequest'
        'Update-GitHubPullRequestBranch'
        'Wait-GitHubWorkflowRun'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'DevOps', 'Actions')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
