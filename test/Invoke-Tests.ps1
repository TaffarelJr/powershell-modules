#Requires -Version 7.0

<#
.SYNOPSIS
    Runs every *.Tests.ps1 under test/, several at a time,
    each in its own PowerShell process with line coverage,
    and exits with the number of files that failed.

.DESCRIPTION
    Coverage measures every *.ps1/*.psm1 under src/, recursively -
    this repo keeps test/ and src/ as top-level siblings,
    so a test's display name (its path under test/, mirrored)
    does not have to resolve to one specific source file for coverage to work;
    each test file exercises the module(s) it imports,
    and Pester attributes whatever actually ran.

    A fresh process per file keeps module state and stubs from leaking
    between files, so each file only has to reset between its own cases -
    that isolation is also what makes running several files at once safe;
    see TaffarelJr.TestRunner's own Invoke-TestRun
    for the -ThrottleLimit that controls how many run concurrently.
    Each file runs under Pester's coverage tracer,
    which writes one Cobertura report per file into the output folder,
    mirroring the test's path.

    A file's own output is shown only when it fails, unless -ShowOutput.

.PARAMETER Path
    One or more folders to search for tests under. Defaults to this
    script's own folder, so the defaults work the same run from the repo
    root or from test/ itself. Narrowing this to one module's folder (e.g.
    test/TaffarelJr.Tally), or a handful of them, only limits the search -
    display names, coverage reports, and result reports still land
    exactly where a full run would put them, since those are always
    computed relative to this script's own folder, not -Path. Mutually
    exclusive with -Module.

.PARAMETER Module
    One or more module names (without the TaffarelJr. prefix), such as
    'Git' or 'Tally'. Shorthand for the matching -Path/-SourceRoot
    pair under this repo's own TaffarelJr.<Name> convention - a CI
    workflow that already knows which module(s) a change touched can
    pass just the name(s) rather than spelling out both paths. Mutually
    exclusive with -Path/-SourceRoot.

.PARAMETER Filter
    A wildcard over the file name, without the .Tests.ps1 suffix.

.PARAMETER OutputPath
    Where the coverage reports go.
    Defaults to a coverage/ folder alongside this script.

.PARAMETER ResultsPath
    Where the JUnit result reports go.
    Defaults to a results/ folder alongside this script.

.PARAMETER SourceRoot
    One or more folders coverage measures, recursively. Defaults to the
    src/ sibling of this script's own folder - this repo's own choice of
    layout, not something TaffarelJr.TestRunner assumes on its own.
    Mutually exclusive with -Module.

.EXAMPLE
    ./test/Invoke-Tests.ps1

.EXAMPLE
    ./Invoke-Tests.ps1 -Filter Write-Success -ShowOutput

.EXAMPLE
    ./Invoke-Tests.ps1 -Module Git
    Runs just TaffarelJr.Git's own tests, coverage scoped to its own
    source - what a per-module CI job would call for the one module a PR
    actually touched.

.EXAMPLE
    ./Invoke-Tests.ps1 -Module Git, Tally

.NOTES
    Every default is anchored on $PSScriptRoot rather than the current directory,
    so the script behaves the same whether it's run as ./test/Invoke-Tests.ps1
    from the repo root or as ./Invoke-Tests.ps1 from inside test/ itself.

    Everything else a run needs - checking Pester is installed, fixing the
    console's encoding, importing whatever each test file is testing - is
    TaffarelJr.TestRunner's own job now, not this script's.
#>
using namespace System.IO

[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(ParameterSetName = 'Path')]
    [string[]]$Path = $PSScriptRoot,

    [Parameter(ParameterSetName = 'Path')]
    [string[]]$SourceRoot = (Join-Path $PSScriptRoot '..' 'src'),

    [Parameter(Mandatory, ParameterSetName = 'Module')]
    [string[]]$Module,

    [string]$Filter = '*',
    [string]$OutputPath = (Join-Path $PSScriptRoot 'coverage'),
    [string]$ResultsPath = (Join-Path $PSScriptRoot 'results'),
    [switch]$ShowOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSCmdlet.ParameterSetName -eq 'Module') {
    # Split apart the same way a comma-joined -Path/-SourceRoot would be -
    # a caller invoked externally (pwsh -File, a CI workflow's own shell
    # step) can only ever bind one bare token per flag to an array
    # parameter, so '-Module Git,Tally' arrives as one element, not two.
    $names = @($Module | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $Path = @($names | ForEach-Object { Join-Path $PSScriptRoot "TaffarelJr.$_" })
    $SourceRoot = @($names | ForEach-Object { Join-Path $PSScriptRoot '..' 'src' "TaffarelJr.$_" })
}

# This repo's own modules aren't published yet, so they aren't on
# PSModulePath the way an installed TaffarelJr.TestRunner's own
# RequiredModules (Tally, ConsoleOutput, ProcessInvocation, RequiredModules)
# would be. Adding src/ here, once, lets Import-Module resolve all of it
# by name below - exactly how it resolves once this repo publishes too.
$srcRoot = Join-Path $PSScriptRoot '..' 'src'
if (($env:PSModulePath -split [Path]::PathSeparator) -notcontains $srcRoot) {
    $env:PSModulePath = $srcRoot, $env:PSModulePath -join [Path]::PathSeparator
}

Import-Module TaffarelJr.TestRunner -Force

$run = Invoke-TestRun `
    -Path $Path `
    -TestRoot $PSScriptRoot `
    -Filter $Filter `
    -OutputPath $OutputPath `
    -ResultsPath $ResultsPath `
    -SourceRoot $SourceRoot `
    -ShowOutput:$ShowOutput
exit $run.ExitCode
