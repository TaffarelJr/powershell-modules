@{
    RootModule           = 'TaffarelJr.UserInput.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '3f142c60-a7a0-4d25-a1ae-d02875295450'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'Interactive prompts for PowerShell scripts: ask for a value or a secret, check the answer and ask again, confirm yes or no, pick from a numbered menu, and read or save an environment variable.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.ConsoleOutput'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'Assert-Input'
        'Confirm-Input'
        'Confirm-Proceed'
        'Get-EnvironmentVariable'
        'Invoke-InputRetry'
        'Read-Input'
        'Read-Secret'
        'Select-Choice'
        'Set-EnvironmentVariable'
        'Test-InteractiveHost'
        'Wait-KeyPress'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @(
                'Input', 'Prompt', 'Console', 'CLI', 'Confirm', 'Choice', 'Secret', 'Environment', 'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.UserInput/CHANGELOG.md'
        }
    }
}
