@{
    RootModule        = 'TaffarelJr.ProcessInvocation.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'daef996b-e984-4603-a047-8c06bd8a7d72'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Runs an external command with its output captured and decoded consistently, throwing a clear error on failure or reporting one that is tolerated - a generic layer a tool-specific wrapper can be built on top of.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Invoke-NativeCommand'
        'Invoke-NativeRead'
        'Assert-ExitCode'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Process', 'NativeCommand', 'ExitCode')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
