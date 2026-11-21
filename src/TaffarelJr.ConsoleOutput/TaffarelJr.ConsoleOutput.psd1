@{
    RootModule        = 'TaffarelJr.ConsoleOutput.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '13991565-6d59-4acf-bc23-e3bf3985e6f8'
    Author            = 'RJ Hollberg'
    CompanyName       = 'RJ Hollberg'
    Copyright         = '(c) 2026 RJ Hollberg.'
    Description       = 'The indent for a PowerShell script''s console output: add and take off levels, get the indent as spaces to print or as a number, reset it after a failure, or run a script block one level in and put the indent back even when the block throws.'
    PowerShellVersion = '7.4'

    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Get-Indent'
        'Get-IndentSize'
        'Invoke-Indented'
        'Pop-Indent'
        'Push-Indent'
        'Reset-Indent'
    )
    CmdletsToExport   = @()
    VariablesToExport = @('DefaultIndentWidth')
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Console', 'Output', 'Indent', 'CLI', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/CHANGELOG.md'
            IconUri      = 'https://raw.githubusercontent.com/TaffarelJr/powershell-modules/main/assets/icon.png'
        }
    }
}
