@{
    RootModule           = 'TaffarelJr.GitHub.Search.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'b1be8dc1-21bb-49d6-86a6-69082e0643c0'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'PowerShell commands to search GitHub for code, commits, issues, pull requests, and repositories, using the GitHub CLI (gh). Each result is an object whose properties you can filter and sort.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules      = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport    = @(
        'Find-GitHubCode'
        'Find-GitHubCommit'
        'Find-GitHubIssue'
        'Find-GitHubPullRequest'
        'Find-GitHubRepository'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'Search', 'Code', 'Issues', 'Query', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Search/CHANGELOG.md'
        }
    }
}
