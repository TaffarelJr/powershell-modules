@{
    RootModule           = 'TaffarelJr.TestRunner.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '9b4a54a5-2553-49bf-b46f-2b68a99272a5'
    Author               = 'RJ Hollberg'
    CompanyName          = 'RJ Hollberg'
    Copyright            = '(c) 2026 RJ Hollberg.'
    Description          = 'Runs test files written with TaffarelJr.TestKit (scripts ending in exit (Complete-TestRun)): every *.Tests.ps1 under a folder, several at a time, each in its own process, with pass, fail or crashed per file and a run summary, and on request under Pester code coverage with JUnit and Cobertura reports.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')

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
            Tags         = @('Testing', 'Pester', 'CodeCoverage', 'TestKit', 'Runner', 'JUnit', 'PSEdition_Core')
            ProjectUri   = 'https://github.com/TaffarelJr/powershell-modules'
            LicenseUri   = 'https://github.com/TaffarelJr/powershell-modules/blob/main/LICENSE'
            ReleaseNotes = 'https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestRunner/CHANGELOG.md'
        }
    }
}
