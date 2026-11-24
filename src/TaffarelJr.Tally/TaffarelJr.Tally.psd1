@{
    RootModule        = 'TaffarelJr.Tally.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'bffa9af5-76cf-41a3-a38e-773903f1eb7a'
    Author            = 'RJ Hollberg'
    CompanyName       = 'RJ Hollberg'
    Copyright         = '(c) 2026 RJ Hollberg.'
    Description       = 'Tagged counters for PowerShell scripts: add to a count under any tags you choose, read the sum of the adds that carry the tags you ask for, or clear them, so one add can be totaled along several dimensions at once.'
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
