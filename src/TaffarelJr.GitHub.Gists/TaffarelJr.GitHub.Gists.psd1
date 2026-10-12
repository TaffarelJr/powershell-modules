@{
    RootModule        = 'TaffarelJr.GitHub.Gists.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'b8a9c0d1-e2f3-46e7-f869-b0c1d2e3f4a5'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Wraps the gh CLI for gists: create, edit, rename files, clone, and delete.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'Copy-GitHubGist'
        'Get-GitHubGist'
        'New-GitHubGist'
        'Remove-GitHubGist'
        'Rename-GitHubGistFile'
        'Set-GitHubGist'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'Gist')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}