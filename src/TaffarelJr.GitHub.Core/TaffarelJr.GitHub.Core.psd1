@{
    RootModule        = 'TaffarelJr.GitHub.Core.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'e3b0c442-98fc-4e1a-9f3c-7f1a2b3c4d5e'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Shared plumbing every other TaffarelJr.GitHub.* module builds on: runs gh with its output captured, parses its JSON into PascalCase objects, and builds the gh api field arguments - plus the raw REST/GraphQL API escape hatch (Invoke-GitHubApi) itself.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'ConvertFrom-GitHubJson'
        'ConvertTo-GitHubFieldArgument'
        'ConvertTo-PascalCaseObject'
        'Invoke-GitHubApi'
        'Invoke-GitHubCommand'
        'Test-GitHubApi'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}