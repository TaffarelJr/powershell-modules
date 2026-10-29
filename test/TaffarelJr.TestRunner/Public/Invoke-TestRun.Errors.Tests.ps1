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
# Arrange - test files to run, a folder to search that is not there, and no report folders yet
$sandbox = New-TestRunnerSandbox
$testRoot = Join-Path $sandbox 'test'
$sourceRoot = Join-Path $sandbox 'src'
New-Item -ItemType Directory -Path $sourceRoot | Out-Null
New-TestFileStub -Directory $testRoot -Name 'One' | Out-Null
$wrapper = New-FakeWrapper -Directory $sandbox -Body "Write-Host '1 passed, 0 failed'"
$outputRoot = Join-Path $sandbox 'coverage'
$resultsRoot = Join-Path $sandbox 'results'
$missing = Join-Path $sandbox 'not-there'
$message = "-Path '$missing' is not an existing folder."

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    # Act - a failing call, whose caller asked for errors to be hidden
    $output = @()
    $caught = $null
    try {
        $output = @(Invoke-TestRun -Path $missing -TestRoot $testRoot -SourceRoot $sourceRoot -Coverage `
                -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper `
                -ErrorAction $preference 6>$null)
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-Equal -Expected 0 -Actual $output.Count `
        -Message "Under -ErrorAction $preference a failing call returns no run"
    Assert-That -Condition (-not (Test-Path -LiteralPath $outputRoot) -and -not (Test-Path -LiteralPath $resultsRoot)) `
        -Message 'and makes no report folder'
    Assert-Equal -Expected 'RuntimeException,Invoke-TestRun' -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the failure is still raised, as a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$caught = $null
try {
    $null = Invoke-TestRun -Path $missing -TestRoot $testRoot -SourceRoot $sourceRoot -Coverage `
        -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Invoke-TestRun' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A folder that is not there raises a terminating error whose ID names the failure and the command'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with a category a caller can act on'
Assert-Equal -Expected $message -Actual $caught.TargetObject `
    -Message 'and the target the failure had, which is its message'
Assert-Equal -Expected $message -Actual $caught.Exception.Message -Message 'and the message of the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
Assert-Throws -ScriptBlock {
    Invoke-TestRun -Path $missing -TestRoot $testRoot -SourceRoot $sourceRoot -Coverage `
        -OutputPath $outputRoot -ResultsPath $resultsRoot -WrapperPath $wrapper -ErrorAction Stop
} -MessageLike '*is not an existing folder*' -Message 'Under -ErrorAction Stop a folder that is not there still throws'

Remove-TestRunnerSandbox -Path $sandbox

exit (Complete-TestRun)
