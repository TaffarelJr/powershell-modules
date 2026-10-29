@{
    RootModule           = 'TaffarelJr.GitHub.Account.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '814cf750-24e2-4861-80e1-3599cd18fb80'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'Manages GitHub sign-in through the GitHub CLI (gh): add, switch, and remove accounts, check who is signed in, list your organizations, and read or change gh''s own settings.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules      = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport    = @(
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
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @(
                'GitHub'
                'gh'
                'CLI'
                'Auth'
                'Authentication'
                'Token'
                'Credential'
                'GitHubCli'
                'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Account/CHANGELOG.md'
        }
    }
}
