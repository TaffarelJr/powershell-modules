@{
    RootModule        = 'TaffarelJr.ConsoleOutput.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '13991565-6d59-4acf-bc23-e3bf3985e6f8'
    Author            = 'RJ Hollberg'
    CompanyName       = 'RJ Hollberg'
    Copyright         = '(c) 2026 RJ Hollberg.'
    Description       = 'Indent-aware status output for PowerShell scripts: success, skip, warning and failure lines, a progress line that is opened and later closed with its outcome, numbered steps, and boxed headers and banners that wrap to the console.'
    PowerShellVersion = '7.4'

    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Clear-Step'
        'Get-CurrentStep'
        'Get-Indent'
        'Invoke-Doing'
        'Invoke-Indented'
        'Pop-Indent'
        'Push-Indent'
        'Write-Banner'
        'Write-Detail'
        'Write-Doing'
        'Write-Done'
        'Write-Failure'
        'Write-Field'
        'Write-Header'
        'Write-Info'
        'Write-Skip'
        'Write-Step'
        'Write-Success'
        'Write-Warn'
    )
    CmdletsToExport   = @()
    VariablesToExport = @('DefaultIndentWidth')
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Console', 'Output', 'CLI', 'Logging', 'Indent', 'Banner', 'Status', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/CHANGELOG.md'
        }
    }
}
