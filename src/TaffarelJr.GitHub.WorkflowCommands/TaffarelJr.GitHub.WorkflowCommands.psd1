@{
    RootModule           = 'TaffarelJr.GitHub.WorkflowCommands.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'af4d4176-413b-4588-b263-030468337341'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'PowerShell commands for the steps of a GitHub Actions workflow: annotate and group the log, hide secrets, and pass outputs, environment variables, PATH changes, summaries, and saved state to later steps. They talk to the runner directly and need no GitHub CLI.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules      = @(
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport    = @(
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
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @(
                'GitHub', 'Actions', 'GitHubActions', 'CI', 'DevOps', 'Workflow', 'Annotation', 'Output', 'Mask',
                'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.WorkflowCommands/CHANGELOG.md'
        }
    }
}
