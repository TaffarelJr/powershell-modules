@{
    RootModule        = 'TaffarelJr.TestKit.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '3fcc10a8-fa0e-4d8a-9986-5d378a6b5d52'
    Author            = 'RJ Hollberg'
    CompanyName       = 'RJ Hollberg'
    Copyright         = '(c) 2026 RJ Hollberg.'
    Description       = 'A small test kit for PowerShell test files written as plain scripts rather than Pester blocks: strict assertions, a pass/fail count that becomes the file''s exit code, and helpers that capture what code printed or what -WhatIf would have done.'
    PowerShellVersion = '7.4'

    CompatiblePSEditions = @('Core')

    FunctionsToExport = @(
        'Assert-Equal'
        'Assert-That'
        'Assert-Throws'
        'Complete-TestRun'
        'Get-HostOutput'
        'Get-WarningOutput'
        'Get-WhatIfOutput'
        'Skip-TestRun'
        'Use-SplitLocation'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Testing', 'Assert', 'Assertion', 'Test', 'TestKit', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestKit/CHANGELOG.md'
        }
    }
}
