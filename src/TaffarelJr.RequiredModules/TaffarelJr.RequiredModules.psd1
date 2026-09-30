@{
    RootModule           = 'TaffarelJr.RequiredModules.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '0bc59b47-b5c6-42ba-b33f-857c68833ad2'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'Declares the PowerShell Gallery modules a script needs in a small manifest, then checks them, installs what is missing without a prompt, updates them to the newest version, and imports them, on a developer''s machine and in CI alike.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Assert-RequiredModule'
        'Get-RequiredModule'
        'Import-RequiredModule'
        'Install-RequiredModule'
        'Test-RequiredModule'
        'Update-RequiredModule'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @(
                'Modules', 'Dependencies', 'Bootstrap', 'Install', 'Gallery', 'Manifest', 'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.RequiredModules/CHANGELOG.md'
        }
    }
}
