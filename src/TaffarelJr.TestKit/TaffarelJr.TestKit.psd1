@{
    RootModule        = 'TaffarelJr.TestKit.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '3fcc10a8-fa0e-4d8a-9986-5d378a6b5d52'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'A minimal, homegrown test-writing kit: Assert-That/Assert-Equal/Assert-Throws, a per-file pass/fail tally, and Get-HostOutput for capturing what a script block printed via Write-Host.'
    PowerShellVersion = '7.0'

    FunctionsToExport = @(
        'Assert-That'
        'Assert-Equal'
        'Assert-Throws'
        'Complete-TestRun'
        'Get-HostOutput'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Testing', 'Assert', 'TestKit')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
