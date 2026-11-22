@{
    RootModule        = 'TaffarelJr.ConsoleOutput.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '13991565-6d59-4acf-bc23-e3bf3985e6f8'
    Author            = 'RJ Hollberg'
    CompanyName       = 'RJ Hollberg'
    Copyright         = '(c) 2026 RJ Hollberg.'
    Description       = 'Indent-aware console output for PowerShell scripts: boxed banners, headers, and status lines (detail, failure, info, skip, success and warning) with their own emoji markers and colors, printed at an indent you add and take off levels of, or run a script block one level in.'
    PowerShellVersion = '7.6'

    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Get-Indent'
        'Get-IndentSize'
        'Invoke-Indented'
        'Pop-Indent'
        'Push-Indent'
        'Reset-Indent'
        'Show-Banner'
        'Show-Detail'
        'Show-Failure'
        'Show-Header'
        'Show-Info'
        'Show-Skip'
        'Show-Success'
        'Show-Warning'
    )
    CmdletsToExport   = @()
    VariablesToExport = @('DefaultIndentWidth')
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Banner', 'CLI', 'Console', 'Header', 'Indent', 'Output', 'PSEdition_Core', 'Status')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/CHANGELOG.md'
            IconUri      = 'https://raw.githubusercontent.com/TaffarelJr/powershell-modules/main/assets/icon.png'
        }
    }
}
