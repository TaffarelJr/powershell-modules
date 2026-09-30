#Requires -Version 7.0

<#
.SYNOPSIS
    Runs every *.Tests.ps1 under test/,
    each in its own PowerShell process with line coverage,
    and exits with the number of files that failed.

.DESCRIPTION
    Coverage measures every *.ps1/*.psm1 under src/, recursively -
    this repo keeps test/ and src/ as top-level siblings,
    so a test's display name (its path under test/, mirrored)
    does not have to resolve to one specific source file for coverage to work;
    each test file exercises the module(s) it imports,
    and Pester attributes whatever actually ran.

    A fresh process per file keeps module state and stubs from leaking between files,
    so each file only has to reset between its own cases.
    Each file runs under Pester's coverage tracer,
    which writes one Cobertura report per file into the output folder,
    mirroring the test's path.

    A file's own output is shown only when it fails, unless -ShowOutput.

.PARAMETER Path
    The folder holding the tests.
    Defaults to 'test' under the current directory.

.PARAMETER Filter
    A wildcard over the file name, without the .Tests.ps1 suffix.

.PARAMETER OutputPath
    Where the coverage reports go. Defaults to 'test/coverage'.

.PARAMETER ResultsPath
    Where the JUnit result reports go. Defaults to 'test/results'.

.PARAMETER SourceRoot
    The folder coverage measures, recursively.
    Defaults to 'src' under the current directory -
    this repo's own choice of layout,
    not something TaffarelJr.TestRunner assumes on its own.

.EXAMPLE
    ./test/Invoke-Tests.ps1

.EXAMPLE
    ./test/Invoke-Tests.ps1 -Filter Write-Success -ShowOutput
#>
using namespace System.Text

[CmdletBinding()]
param(
    [string]$Path = 'test',
    [string]$Filter = '*',
    [string]$OutputPath = 'test/coverage',
    [string]$ResultsPath = 'test/results',
    [string]$SourceRoot = 'src',
    [switch]$ShowOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..' 'src' 'TaffarelJr.ConsoleOutput' 'TaffarelJr.ConsoleOutput.psd1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'src' 'TaffarelJr.UserInput' 'TaffarelJr.UserInput.psd1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'src' 'TaffarelJr.RequiredModules' 'TaffarelJr.RequiredModules.psd1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'src' 'TaffarelJr.Tally' 'TaffarelJr.Tally.psd1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'src' 'TaffarelJr.ProcessInvocation' 'TaffarelJr.ProcessInvocation.psd1') -Force
Import-Module (Join-Path $PSScriptRoot '..' 'src' 'TaffarelJr.TestRunner' 'TaffarelJr.TestRunner.psd1') -Force

# The files print UTF-8 (the console markers);
# without this a Windows console decodes their output as its legacy code page.
[Console]::OutputEncoding = [UTF8Encoding]::new()

# Checked once, here,
# rather than by every child process Invoke-TestFile.ps1 spawns -
# installing from N processes at once would race.
# Pester is the only thing this repo's own tests need declared;
# RequiredModules.psd1 is where a future module's tests would add their own.
Assert-RequiredModule -Path (Join-Path $PSScriptRoot 'RequiredModules.psd1')

$run = Invoke-TestRun `
    -Path $Path `
    -Filter $Filter `
    -OutputPath $OutputPath `
    -ResultsPath $ResultsPath `
    -SourceRoot $SourceRoot `
    -WrapperPath (Join-Path $PSScriptRoot 'Invoke-TestFile.ps1') `
    -ShowOutput:$ShowOutput
exit $run.ExitCode
