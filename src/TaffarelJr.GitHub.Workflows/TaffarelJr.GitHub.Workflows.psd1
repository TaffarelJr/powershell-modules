@{
    RootModule        = 'TaffarelJr.GitHub.Workflows.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'f6e7a8b9-c0d1-44c5-d647-f8a9b0c1d2e3'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Wraps the gh CLI for GitHub Actions: dispatch and monitor workflow runs, manage workflows, and clear Actions caches.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
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
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'Actions', 'DevOps')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}