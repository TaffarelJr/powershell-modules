@{
    RootModule        = 'TaffarelJr.RequiredModules.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '0bc59b47-b5c6-42ba-b33f-857c68833ad2'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Declares the PowerShell Gallery modules a script needs in a RequiredModules.psd1 manifest, then checks, installs (interactively or with a clear CI failure), and imports them.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.UserInput'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'Get-RequiredModule'
        'Test-RequiredModule'
        'Install-RequiredModule'
        'Import-RequiredModule'
        'Assert-RequiredModule'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Modules', 'Dependencies', 'Bootstrap')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
