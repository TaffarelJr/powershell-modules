@{
    RootModule           = 'TaffarelJr.GitHub.Releases.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '4ba93e24-74ef-40a5-9c36-ace35dc05e62'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'PowerShell commands to create, edit, publish, and delete GitHub releases, and to upload, download, and remove their assets, using the GitHub CLI (gh). A release comes back as an object that pipes into the commands that change it.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules      = @(
        @{ ModuleName = 'TaffarelJr.GitHub.Core'; ModuleVersion = '0.1.0' }
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport    = @(
        'Add-GitHubReleaseAsset'
        'Get-GitHubRelease'
        'New-GitHubRelease'
        'Remove-GitHubRelease'
        'Remove-GitHubReleaseAsset'
        'Save-GitHubReleaseAsset'
        'Set-GitHubRelease'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @('GitHub', 'gh', 'CLI', 'Release', 'Releases', 'Asset', 'Download', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Releases/CHANGELOG.md'
        }
    }
}
