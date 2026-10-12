@{
    RootModule        = 'TaffarelJr.VSCode.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'ca437f30-a00a-470f-9d05-102f18f42ebe'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Finds and launches Visual Studio Code, and authors multi-root .code-workspace files: folders, settings (optionally mirrored from a folder''s own .vscode/settings.json), and recommended extensions.'
    PowerShellVersion = '7.0'

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
            Tags         = @('VSCode', 'VisualStudioCode', 'Workspace', 'Editor')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
