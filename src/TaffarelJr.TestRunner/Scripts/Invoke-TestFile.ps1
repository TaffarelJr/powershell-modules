#Requires -Version 7.0

<#
.SYNOPSIS
    Runs one test file under Pester's coverage tracer,
    writes its Cobertura report, and exits with the file's own exit code.
    This is Invoke-TestRun's own default -WrapperPath -
    override it only for a different Pester configuration.

.DESCRIPTION
    Pester is only the coverage collector and the JUnit exporter.
    The file runs as-is inside one It block:
    its assertions, its tally line, and its `exit` are its own
    and pass straight through, which is what Invoke-TestFileProcess reads.
    Pester's own output is off so nothing else lands in between.

    -SourceRoot is for coverage only - this wrapper never imports anything
    under it itself. A test file imports what it needs, the same way it
    always has (see Import-LocalModule); the alternative, importing
    everything under -SourceRoot for every single file, would load modules
    a given file never asked for, for every file in an entire run.

    The It block itself throws whenever the file exits non-zero, not just
    when running it throws outright - otherwise every file reports as
    "passed" in Pester's own verdict (and so in the JUnit report) purely
    because running it didn't itself raise an exception, regardless of
    how many of its own assertions actually failed.

    Pester is assumed already installed - a caller checks that once,
    up front, rather than every child process repeating the check.

.PARAMETER TestFile
    The *.Tests.ps1 to run.

.PARAMETER SourceRoot
    One or more src/ folders coverage measures, recursively, test files
    excluded - joined with the platform path separator, since a value
    arriving as a command-line argument can only ever bind one bare token
    to a [string[]] parameter.

.PARAMETER OutputPath
    The Cobertura XML to write.

.PARAMETER ResultPath
    The JUnit XML to write.
#>
using namespace System.IO

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TestFile,
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][string]$ResultPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceRootPaths = $SourceRoot -split [regex]::Escape([Path]::PathSeparator)

Import-Module -Name Pester -MinimumVersion 5.0 -Force

$state = @{ ExitCode = 1 } # Stays 1 - crashed - unless the file reaches its own exit.

$container = New-PesterContainer -Data @{
    TestFile = $TestFile
    State    = $state
} -ScriptBlock {
    param([string]$TestFile, [hashtable]$State)

    Describe $TestFile {
        It 'runs to its own exit' {
            & $TestFile
            $State.ExitCode = $LASTEXITCODE
            if ($LASTEXITCODE -ne 0) {
                throw "Exited with code $LASTEXITCODE - see the file's own captured output for which case(s) failed."
            }
        }
    }
}

$configuration = New-PesterConfiguration
$configuration.Run.Container = $container
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'None'
$configuration.CodeCoverage.Enabled = $true
$configuration.CodeCoverage.Path = $sourceRootPaths
$configuration.CodeCoverage.ExcludeTests = $true
$configuration.CodeCoverage.OutputFormat = 'Cobertura'
$configuration.CodeCoverage.OutputPath = $OutputPath
# Breakpoints need a debugger, which a -NonInteractive host does not have.
$configuration.CodeCoverage.UseBreakpoints = $false
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = 'JUnitXml'
$configuration.TestResult.OutputPath = $ResultPath

$run = Invoke-Pester -Configuration $configuration

# With Pester's output off, a crash inside the file would otherwise vanish.
foreach ($test in $run.Failed) {
    foreach ($record in $test.ErrorRecord) {
        Write-Host $record.Exception.Message
        Write-Host $record.ScriptStackTrace
    }
}

exit $state.ExitCode
