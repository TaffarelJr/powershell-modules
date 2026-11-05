#Requires -Version 7.4
using namespace System.IO
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
# Arrange - a wrapper that leaves a mark when it runs, and a source root that cannot cross into the process
$sandbox = New-TestRunnerSandbox
$marker = Join-Path $sandbox 'ran.txt'
$wrapper = New-FakeWrapper -Directory $sandbox -Body @"
Set-Content -LiteralPath '$marker' -Value 'ran'
Write-Host '1 passed, 0 failed'
"@
$separator = [Path]::PathSeparator
$badRoot = Join-Path $sandbox "src${separator}x"
$message = "-SourceRoot entry '$badRoot' contains '$separator', which separates the list handed to the wrapper."
$call = @{
    File        = Join-Path $sandbox 'Some.Tests.ps1'
    Name        = 'Some'
    SourceRoot  = $badRoot
    Coverage    = $true
    ReportPath  = Join-Path $sandbox 'report.xml'
    ResultPath  = Join-Path $sandbox 'result.xml'
    WrapperPath = $wrapper
}

foreach ($preference in 'SilentlyContinue', 'Ignore') {
    # Act - a failing call, whose caller asked for errors to be hidden
    $output = @()
    $caught = $null
    try {
        $output = @(Invoke-TestFileProcess @call -ErrorAction $preference)
    }
    catch {
        $caught = $_
    }

    # Assert
    Assert-That -Condition (-not (Test-Path -LiteralPath $marker)) `
        -Message "Under -ErrorAction $preference a source root that cannot be handed on starts no process"
    Assert-Equal -Expected 0 -Actual $output.Count -Message 'and returns no result'
    Assert-Equal -Expected 'RuntimeException,Invoke-TestFileProcess' -Actual $caught.FullyQualifiedErrorId `
        -Message 'and the failure is still raised, as a terminating error'
}

#───────────────────────────────────────────────────────────────────────────────
# Act
$caught = $null
try {
    $null = Invoke-TestFileProcess @call
}
catch {
    $caught = $_
}

# Assert
Assert-Equal -Expected 'RuntimeException,Invoke-TestFileProcess' -Actual $caught.FullyQualifiedErrorId `
    -Message 'A source root that cannot be handed on raises a terminating error, with the failure and command in its ID'
Assert-Equal -Expected ([ErrorCategory]::InvalidOperation) -Actual $caught.CategoryInfo.Category `
    -Message 'with a category a caller can act on'
Assert-Equal -Expected $message -Actual $caught.TargetObject `
    -Message 'and the target the failure had, which is its message'
Assert-Equal -Expected $message -Actual $caught.Exception.Message -Message 'and the message of the failure'

#───────────────────────────────────────────────────────────────────────────────
# Arrange / Act / Assert
Assert-Throws -ScriptBlock { Invoke-TestFileProcess @call -ErrorAction Stop } `
    -MessageLike '*which separates the list handed to the wrapper*' `
    -Message 'Under -ErrorAction Stop a source root that cannot be handed on still throws'
Assert-That -Condition (-not (Test-Path -LiteralPath $marker)) -Message 'and starts no process'

Remove-TestRunnerSandbox -Path $sandbox

exit (Complete-TestRun)
