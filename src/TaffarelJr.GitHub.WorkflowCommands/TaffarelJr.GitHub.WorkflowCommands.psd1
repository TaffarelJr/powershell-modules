@{
    RootModule        = 'TaffarelJr.GitHub.WorkflowCommands.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'af4d4176-413b-4588-b263-030468337341'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'The GitHub Actions runner protocol: log annotations, masking, step outputs, environment variables, PATH, job summaries, and action state. No gh CLI or API calls - this talks to the runner itself.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
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
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('GitHub', 'Actions', 'CI', 'DevOps', 'Workflow')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
