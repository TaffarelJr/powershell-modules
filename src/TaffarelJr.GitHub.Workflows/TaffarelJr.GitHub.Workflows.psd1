@{
    RootModule           = 'TaffarelJr.GitHub.Workflows.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'd908f8ea-0486-4825-8094-96f7b3eb46a4'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'PowerShell commands to run and manage GitHub Actions through the GitHub CLI (gh): dispatch a workflow and wait for its run, rerun or cancel runs, download artifacts, and clear caches. Workflows, runs, and caches come back as objects that pipe into the commands that act on them.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules      = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport    = @(
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
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @(
                'GitHub', 'gh', 'CLI', 'Actions', 'GitHubActions', 'DevOps', 'Workflow', 'Run', 'Cache', 'Artifact',
                'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Workflows/CHANGELOG.md'
        }
    }
}
