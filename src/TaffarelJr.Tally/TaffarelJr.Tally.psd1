@{
    RootModule        = 'TaffarelJr.Tally.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'bffa9af5-76cf-41a3-a38e-773903f1eb7a'
    Author            = 'RJ Hollberg'
    CompanyName       = 'RJ Hollberg'
    Copyright         = '(c) 2026 RJ Hollberg.'
    Description       = 'Named counters for PowerShell scripts: add to a count by name, read it back, clear it, turn the counts into one line of text to print or log, and read such a line back into counts.'
    PowerShellVersion = '7.4'

    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Add-Tally'
        'Clear-Tally'
        'Format-Tally'
        'Get-Tally'
        'Read-Tally'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Counter', 'Tally', 'Count', 'Summary', 'Reporting', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/CHANGELOG.md'
        }
    }
}
