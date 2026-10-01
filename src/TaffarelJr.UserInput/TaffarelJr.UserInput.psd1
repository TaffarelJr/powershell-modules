@{
    RootModule        = 'TaffarelJr.UserInput.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '3f142c60-a7a0-4d25-a1ae-d02875295450'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Small, composable interactive-prompting primitives: read a value or a secret, validate it, retry on failure, confirm yes/no, pick from a menu, and check or persist an environment variable - assembled by the caller rather than one do-everything function.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.ConsoleOutput'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'Read-Input'
        'Read-Secret'
        'Assert-Input'
        'Get-EnvironmentVariable'
        'Set-EnvironmentVariable'
        'Invoke-InputRetry'
        'Confirm-Input'
        'Confirm-Proceed'
        'Select-Choice'
        'Test-InteractiveHost'
        'Wait-KeyPress'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Input', 'Prompt', 'Console', 'CLI')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
