@{
    RootModule        = 'TaffarelJr.GitHub.Account.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a1f2b3c4-d5e6-4f70-8192-a3b4c5d6e7f8'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Wraps the gh CLI''s own authentication: accounts, credential-helper setup, organization membership, and gh''s own local configuration.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'Clear-GitHubConfigCache'
        'Connect-GitHubAccount'
        'Disconnect-GitHubAccount'
        'Get-GitHubAuthStatus'
        'Get-GitHubConfig'
        'Get-GitHubOrganization'
        'Get-GitHubToken'
        'Register-GitHubCredentialHelper'
        'Set-GitHubConfig'
        'Switch-GitHubAccount'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'Auth')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}