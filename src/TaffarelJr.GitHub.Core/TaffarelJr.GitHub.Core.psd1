@{
    RootModule           = 'TaffarelJr.GitHub.Core.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '4e7b883d-b8eb-450c-bef7-e8911a4b9490'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'The shared groundwork of the TaffarelJr.GitHub.* modules, which drive the GitHub CLI (gh): call the GitHub REST or GraphQL API from a script, and read gh''s JSON as PowerShell objects, with credentials kept out of every message.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules      = @(
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport    = @(
        'Assert-GitHubHostname'
        'Assert-GitHubPollRead'
        'Assert-GitHubSameRepository'
        'ConvertFrom-GitHubJson'
        'ConvertTo-GitHubCsvField'
        'ConvertTo-GitHubFieldArgument'
        'ConvertTo-GitHubJsonFieldList'
        'ConvertTo-GitHubRepositoryReference'
        'ConvertTo-PascalCaseObject'
        'Format-GitHubRepositoryName'
        'Get-GitHubTimeoutMessage'
        'Invoke-GitHubApi'
        'Invoke-GitHubCommand'
        'New-GitHubPoll'
        'Resolve-GitHubInputFile'
        'Resolve-GitHubItemReference'
        'Resolve-GitHubPath'
        'Resolve-GitHubRepositoryArgument'
        'Test-GitHubApi'
        'Test-GitHubPollExpired'
        'Use-GitHubTextFile'
        'Wait-GitHubPoll'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'Api', 'Json', 'GitHubCli', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/CHANGELOG.md'
        }
    }
}
