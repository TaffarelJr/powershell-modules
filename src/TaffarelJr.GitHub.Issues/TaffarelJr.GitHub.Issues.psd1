@{
    RootModule        = 'TaffarelJr.GitHub.Issues.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'd4c5e6f7-a8b9-42a3-b425-d6e7f8a9b0c1'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Wraps the gh CLI for issues: create, edit, comment, transfer, and manage their lifecycle.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
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
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'Issue')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}