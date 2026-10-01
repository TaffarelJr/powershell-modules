@{
    RootModule        = 'TaffarelJr.FileText.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '93a0cf9a-c2ca-4a35-9f61-2ce483c1bd56'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Reads and writes text files without disturbing their existing encoding or line ending, and replaces a placeholder token across a whole directory tree - file content, file names, and directory names - built on the same encoding-safe read/write.'
    PowerShellVersion = '7.0'

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
            Tags         = @('File', 'Text', 'Encoding', 'BOM')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
