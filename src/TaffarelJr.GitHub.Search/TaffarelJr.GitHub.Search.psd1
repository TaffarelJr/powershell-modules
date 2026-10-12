@{
    RootModule        = 'TaffarelJr.GitHub.Search.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a7f8b9c0-d1e2-45d6-e758-a9b0c1d2e3f4'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Wraps the gh CLI to search GitHub: code, commits, issues, pull requests, and repositories.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'Find-GitHubCode'
        'Find-GitHubCommit'
        'Find-GitHubIssue'
        'Find-GitHubPullRequest'
        'Find-GitHubRepository'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'Search')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}