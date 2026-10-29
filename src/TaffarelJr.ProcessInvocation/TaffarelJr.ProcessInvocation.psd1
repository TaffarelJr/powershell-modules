@{
    RootModule        = 'TaffarelJr.ProcessInvocation.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'daef996b-e984-4603-a047-8c06bd8a7d72'
    Author            = 'RJ Hollberg'
    CompanyName       = 'RJ Hollberg'
    Copyright         = '(c) 2026 RJ Hollberg.'
    Description       = 'Runs external commands such as git with their output captured, throwing a clear error when one fails or returning the outcome instead, and hides URL credentials and secrets in every message.'
    PowerShellVersion = '7.4'

    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Assert-ExitCode'
        'Hide-MaskedValue'
        'Hide-UrlCredential'
        'Invoke-NativeCommand'
        'Invoke-NativeRead'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @(
                'Process', 'NativeCommand', 'ExitCode', 'Invoke', 'Credential', 'Mask', 'Timeout', 'Stderr',
                'PSEdition_Core'
            )
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ProcessInvocation/CHANGELOG.md'
        }
    }
}
