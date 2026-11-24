@{
    RootModule        = 'TaffarelJr.Tally.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'bffa9af5-76cf-41a3-a38e-773903f1eb7a'
    Author            = 'RJ Hollberg'
    CompanyName       = 'RJ Hollberg'
    Copyright         = '(c) 2026 RJ Hollberg.'
    Description       = 'Tagged counters for PowerShell scripts: add to the count of each tag you choose, read every count as a name and a value to sort, total, show or hand to another process, or clear them.'
    PowerShellVersion = '7.6'

    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Add-Tally'
        'Clear-Tally'
        'Get-Tally'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Count', 'Counter', 'PSEdition_Core', 'Reporting', 'Summary', 'Tally')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/CHANGELOG.md'
            IconUri      = 'https://raw.githubusercontent.com/TaffarelJr/powershell-modules/main/assets/icon.png'
        }
    }
}
