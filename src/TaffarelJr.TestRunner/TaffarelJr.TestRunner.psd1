@{
    RootModule        = 'TaffarelJr.TestRunner.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = '9b4a54a5-2553-49bf-b46f-2b68a99272a5'
    Author            = 'TaffarelJr'
    CompanyName       = 'TaffarelJr'
    Copyright         = '(c) TaffarelJr.'
    Description       = 'Runs every *.Tests.ps1 under a folder, several at a time, each in its own process under a Pester coverage wrapper, and reports pass/fail/crashed per file plus a run summary.'
    PowerShellVersion = '7.0'

    RequiredModules   = @(
        @{ ModuleName = 'TaffarelJr.Tally'; ModuleVersion = '0.1.0' }
        @{ ModuleName = 'TaffarelJr.ConsoleOutput'; ModuleVersion = '0.1.0' }
        @{ ModuleName = 'TaffarelJr.ProcessInvocation'; ModuleVersion = '0.1.0' }
        @{ ModuleName = 'TaffarelJr.RequiredModules'; ModuleVersion = '0.1.0' }
    )

    FunctionsToExport = @(
        'Import-LocalModule'
        'Invoke-TestFileProcess'
        'Invoke-TestRun'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Testing', 'Pester', 'CodeCoverage')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            ReleaseNotes = 'See CHANGELOG.md.'
        }
    }
}
