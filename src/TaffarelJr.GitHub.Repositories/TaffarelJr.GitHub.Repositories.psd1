@{
    RootModule        = 'TaffarelJr.GitHub.Repositories.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b2a3c4d5-e6f7-4081-9203-b4c5d6e7f8a9'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Wraps the gh CLI for repository administration: create, edit, delete, fork, sync, deploy keys, labels, rulesets, secrets, and variables.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
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
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'Repository')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}