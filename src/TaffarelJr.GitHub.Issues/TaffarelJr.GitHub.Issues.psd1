@{
    RootModule           = 'TaffarelJr.GitHub.Issues.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'cd7f2b5e-c6e5-4972-b950-2e47625d9a55'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'Works with GitHub issues through the GitHub CLI (gh): create, edit, comment on, move, and close them, and read them back.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules      = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport    = @(
        'Add-GitHubIssueComment'
        'Close-GitHubIssue'
        'Get-GitHubIssue'
        'Get-GitHubIssueStatus'
        'Lock-GitHubIssue'
        'Move-GitHubIssue'
        'New-GitHubIssue'
        'Open-GitHubIssue'
        'Remove-GitHubIssue'
        'Set-GitHubIssue'
        'Unlock-GitHubIssue'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @(
                'GitHub'
                'gh'
                'CLI'
                'Issue'
                'Issues'
                'Labels'
                'Comments'
                'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Issues/CHANGELOG.md'
        }
    }
}
