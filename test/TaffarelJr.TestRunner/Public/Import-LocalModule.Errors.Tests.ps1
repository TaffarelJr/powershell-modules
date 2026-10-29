#Requires -Version 7.4
using namespace System.Management.Automation

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Get-Item $PSScriptRoot).Parent.Parent.Parent.FullName
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.Tally/TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestKit/TaffarelJr.TestKit.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ConsoleOutput/TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.ProcessInvocation/TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.RequiredModules/TaffarelJr.RequiredModules.psd1') -Force
Import-Module (Join-Path $repoRoot 'src/TaffarelJr.TestRunner/TaffarelJr.TestRunner.psd1') -Force
. (Join-Path $PSScriptRoot '..' 'TestRunnerTestHelper.ps1')

#───────────────────────────────────────────────────────────────────────────────
# Arrange - a folder that is not there, and a folder whose module cannot be imported
$sandbox = New-TestRunnerSandbox
try {
    $missing = Join-Path $sandbox 'not-there'
    $message = "Not a module folder: $missing - pass the folder that holds the module's .psd1 or .psm1."
    $broken = Join-Path $sandbox 'BrokenModule'
    New-Item -ItemType Directory -Path $broken | Out-Null
    Set-Content -LiteralPath (Join-Path $broken 'BrokenModule.psm1') -Value "throw 'the module cannot load'"

    foreach ($preference in 'SilentlyContinue', 'Ignore') {
        # Act - a failing call, whose caller asked for errors to be hidden
        $caught = $null
        try {
            Import-LocalModule -Path $missing -ErrorAction $preference
        }
        catch {
            $caught = $_
        }

        # Assert
        Assert-Equal -Expected 'RuntimeException,Import-LocalModule' -Actual $caught.FullyQualifiedErrorId `
            -Message "Under -ErrorAction $preference a folder that is not there is still raised, as a terminating error"
    }

    #───────────────────────────────────────────────────────────────────────────
    # Act
    $caught = $null
    try {
        Import-LocalModule -Path $missing
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 'RuntimeException,Import-LocalModule' -Actual $caught.FullyQualifiedErrorId `
        -Message 'A folder that is not there raises a terminating error whose ID names the failure and the command'
    Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
        -Message 'with a category a caller can act on'
    Assert-Equal -Expected $message -Actual $caught.TargetObject `
        -Message 'and the target the failure had, which is its message'
    Assert-Equal -Expected $message -Actual $caught.Exception.Message -Message 'and the message of the failure'

    #───────────────────────────────────────────────────────────────────────────
    # Arrange / Act / Assert
    Assert-Throws -ScriptBlock { Import-LocalModule -Path $missing -ErrorAction Stop } `
        -MessageLike '*Not a module folder*' `
        -Message 'Under -ErrorAction Stop a folder that is not there still throws'

    #───────────────────────────────────────────────────────────────────────────
    # Act - a module that is found but fails while it loads, with errors hidden
    $caught = $null
    try {
        Import-LocalModule -Path $broken -ErrorAction SilentlyContinue
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-That -Condition ($null -ne $caught) -Message 'A module that fails to load is raised even with errors hidden'
    Assert-That -Condition ($caught.Exception.Message -like '*the module cannot load*') `
        -Message 'with the module''s own message'
    Assert-Equal -Expected 0 -Actual @(Get-Module -Name 'BrokenModule').Count -Message 'and is not left loaded'
}
finally {
    Remove-TestRunnerSandbox -Path $sandbox
}

exit (Complete-TestRun)
