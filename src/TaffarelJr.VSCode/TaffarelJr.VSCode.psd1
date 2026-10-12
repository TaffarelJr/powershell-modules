@{
    RootModule           = 'TaffarelJr.VSCode.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'ca437f30-a00a-470f-9d05-102f18f42ebe'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'Finds and launches Visual Studio Code, and writes multi-root .code-workspace files with their folders, settings (optionally copied from a folder''s own .vscode/settings.json) and recommended extensions.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.FileText'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'Get-VSCodeExecutable'
        'New-VSCodeWorkspaceFile'
        'Start-VSCode'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @(
                'VSCode', 'VisualStudioCode', 'Workspace', 'Editor', 'Launch', 'Settings', 'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.VSCode/CHANGELOG.md'
        }
    }
}
