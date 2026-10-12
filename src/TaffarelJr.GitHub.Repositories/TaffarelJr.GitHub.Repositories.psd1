@{
    RootModule           = 'TaffarelJr.GitHub.Repositories.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'a3fcc890-950c-473c-a996-02c24531483f'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'Creates, configures, and removes GitHub repositories through the GitHub CLI (gh), and manages what belongs to them: labels, secrets, variables, deploy keys, and rulesets.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules      = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport    = @(
        'Add-GitHubDeployKey'
        'Copy-GitHubLabel'
        'Get-GitHubDefaultRepository'
        'Get-GitHubDeployKey'
        'Get-GitHubLabel'
        'Get-GitHubRepository'
        'Get-GitHubRuleset'
        'Get-GitHubRulesetCheck'
        'Get-GitHubSecret'
        'Get-GitHubVariable'
        'New-GitHubFork'
        'New-GitHubLabel'
        'New-GitHubRepository'
        'Remove-GitHubDeployKey'
        'Remove-GitHubLabel'
        'Remove-GitHubRepository'
        'Remove-GitHubSecret'
        'Remove-GitHubVariable'
        'Rename-GitHubRepository'
        'Set-GitHubDefaultRepository'
        'Set-GitHubLabel'
        'Set-GitHubRepository'
        'Set-GitHubSecret'
        'Set-GitHubVariable'
        'Sync-GitHubRepository'
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
                'Repository'
                'Secrets'
                'Variables'
                'Labels'
                'Rulesets'
                'DeployKey'
                'Fork'
                'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Repositories/CHANGELOG.md'
        }
    }
}
