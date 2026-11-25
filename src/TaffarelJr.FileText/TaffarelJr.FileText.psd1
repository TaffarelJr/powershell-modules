@{
    RootModule        = 'TaffarelJr.FileText.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '93a0cf9a-c2ca-4a35-9f61-2ce483c1bd56'
    Author            = 'RJ Hollberg'
    CompanyName       = 'RJ Hollberg'
    Copyright         = '(c) 2026 RJ Hollberg.'
    Description       = 'Reads what a text file is written in, for scripts that rewrite text without disturbing it: the line ending a piece of text uses, and the encoding a file is in, from its byte order mark.'
    PowerShellVersion = '7.6'

    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Get-FileEncoding'
        'Get-LineEnding'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('BOM', 'Encoding', 'File', 'LineEnding', 'PSEdition_Core', 'Text')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.FileText/CHANGELOG.md'
            IconUri      = 'https://raw.githubusercontent.com/TaffarelJr/powershell-modules/main/assets/icon.png'
        }
    }
}
