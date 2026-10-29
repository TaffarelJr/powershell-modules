@{
    RootModule           = 'TaffarelJr.FileText.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '93a0cf9a-c2ca-4a35-9f61-2ce483c1bd56'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'Reads and writes text files without losing their encoding, byte order mark or line endings, and replaces a placeholder token across a whole folder tree: in file content, file names and folder names.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Get-FileEncoding'
        'Get-LineEnding'
        'Read-TextFile'
        'Rename-Token'
        'Update-FileToken'
        'Write-TextFile'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @(
                'File', 'Text', 'Encoding', 'BOM', 'LineEnding', 'Rename', 'Token', 'Template', 'Utf8', 'Unicode',
                'Replace', 'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.FileText/CHANGELOG.md'
        }
    }
}
