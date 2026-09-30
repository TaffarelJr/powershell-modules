@{
    RootModule        = 'TaffarelJr.ConsoleOutput.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '13991565-6d59-4acf-bc23-e3bf3985e6f8'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Indent-aware console status output: success/skip/warn/failure lines, Doing/Done progress, step banners, and word-wrapped box-drawn headers/banners.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Push-Indent'
        'Pop-Indent'
        'Get-Indent'
        'Invoke-Indented'
        'Get-CurrentStep'
        'Write-Success'
        'Write-Skip'
        'Write-Warn'
        'Write-Failure'
        'Write-Info'
        'Write-Detail'
        'Write-Field'
        'Write-Doing'
        'Write-Done'
        'Write-Step'
        'Clear-Step'
        'Write-Header'
        'Write-Banner'
    )
    CmdletsToExport   = @()
    VariablesToExport = @('DefaultIndentWidth')
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Console', 'Output', 'CLI', 'Logging')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
