@{
    RootModule           = 'TaffarelJr.GitHub.Gists.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '140410c0-0d21-4623-ae29-b27bba77a84c'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'PowerShell commands to create, read, edit, clone, and delete GitHub gists and rename their files, using the GitHub CLI (gh). A gist comes back as an object with the content of each file ready to read.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules      = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport    = @(
        'Copy-GitHubGist'
        'Get-GitHubGist'
        'New-GitHubGist'
        'Remove-GitHubGist'
        'Rename-GitHubGistFile'
        'Set-GitHubGist'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'Gist', 'Gists', 'Snippet', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Gists/CHANGELOG.md'
        }
    }
}
