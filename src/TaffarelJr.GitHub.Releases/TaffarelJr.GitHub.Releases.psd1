@{
    RootModule        = 'TaffarelJr.GitHub.Releases.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'e5d6f7a8-b9c0-43b4-c536-e7f8a9b0c1d2'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Wraps the gh CLI for releases and their assets: create, edit, publish, upload, and download.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'Add-GitHubReleaseAsset'
        'Get-GitHubRelease'
        'New-GitHubRelease'
        'Remove-GitHubRelease'
        'Remove-GitHubReleaseAsset'
        'Save-GitHubReleaseAsset'
        'Set-GitHubRelease'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'Release')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}