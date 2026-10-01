@{
    RootModule        = 'TaffarelJr.Tally.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'bffa9af5-76cf-41a3-a38e-773903f1eb7a'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'A generic named-counter utility: Add-Tally/Get-Tally/Clear-Tally, Format-Tally to render the running counts as a string a caller can print, log, or append to a job summary, and Read-Tally to parse that same string back.'
    PowerShellVersion = '7.0'

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
            Tags         = @('Counter', 'Tally', 'Reporting')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
