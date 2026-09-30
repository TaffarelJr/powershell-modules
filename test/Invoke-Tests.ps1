#Requires -Version 7.4

<#
.SYNOPSIS
    Runs every *.Tests.ps1 under test/, several at a time,
    each in its own PowerShell process,
    and exits with the number of files that failed.

.DESCRIPTION
    The default run is the unit tier: every test file except the
    integration files, with no coverage and no reports, and no Pester.
    It is the fast run, and the one to repeat while working.

    -Coverage runs each file under Pester's coverage tracer instead,
    which costs seconds a file, and writes one Cobertura report and one
    JUnit result per file into the output folders, mirroring the test's path.
    Coverage measures every *.ps1/*.psm1 under src/, recursively -
    this repo keeps test/ and src/ as top-level siblings,
    so a test's display name (its path under test/, mirrored)
    does not have to resolve to one specific source file for coverage to work;
    each test file exercises the module(s) it imports,
    and Pester attributes whatever actually ran.
    A file under test/<Module>/ is measured over src/<Module> alone.

    -Integration adds the files that need the real tool and a login:
    the *.Live files, which call it against the real service,
    and the *.Contract files, which run it against a loopback server.

    A fresh process per file keeps module state and stubs from leaking
    between files, so each file only has to reset between its own cases -
    that isolation is also what makes running several files at once safe;
    see TaffarelJr.TestRunner's own Invoke-TestRun
    for the -ThrottleLimit that controls how many run concurrently.

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
    A file-system filter over the file name, without the .Tests.ps1 suffix:
    * and ? only - brackets are not a character range.

.PARAMETER OutputPath
    Where the coverage reports go, with -Coverage.
    Defaults to a coverage/ folder alongside this script.

.PARAMETER ResultsPath
    Where the JUnit result reports go, with -Coverage.
    Defaults to a results/ folder alongside this script.

.PARAMETER SourceRoot
    One or more folders. With -Coverage, coverage measures them,
    recursively. Defaults to the src/ sibling of this script's own
    folder - this repo's own choice of layout,
    not something TaffarelJr.TestRunner assumes on its own.
    Mutually exclusive with -Module.

.PARAMETER ShowOutput
    Prints every file's output, not just a failing file's.

.PARAMETER ThrottleLimit
    How many files run at once. Defaults to the processor count; each file
    is its own process, so the limit is about the machine, not isolation.

.PARAMETER TimeoutSeconds
    How long one file may run before it is stopped and counted as crashed.
    Defaults to no limit.

.PARAMETER Coverage
    Runs each file under Pester's coverage tracer and writes the coverage
    and result reports. Needs Pester, which is installed when missing.
    Without it no Pester is loaded and nothing is written.

.PARAMETER Integration
    Also runs the *.Live and *.Contract files. They need the real tool
    (gh, for the GitHub modules) and a login, so they are off by default.

.EXAMPLE
    ./test/Invoke-Tests.ps1 -Module Git
    Runs just TaffarelJr.Git's own unit tests - no coverage, no reports -
    what a quick check of the one module a change touched would call for.

.EXAMPLE
    ./Invoke-Tests.ps1 -Module Git -Coverage
    Runs the same tests under coverage, scoped to the module's own
    source, and writes the reports.

.EXAMPLE
    ./Invoke-Tests.ps1 -Filter Write-Success -ShowOutput

.EXAMPLE
    ./Invoke-Tests.ps1 -Module Git, Tally

.EXAMPLE
    ./test/Invoke-Tests.ps1 -Integration -Coverage
    Runs every test file, integration ones too, under coverage -
    the shape a CI job takes.

.NOTES
    Every default is anchored on $PSScriptRoot rather than the current directory,
    so the script behaves the same whether it's run as ./test/Invoke-Tests.ps1
    from the repo root or as ./Invoke-Tests.ps1 from inside test/ itself.

    Everything else a run needs - checking Pester is installed, fixing the
    console's encoding, importing whatever each test file is testing - is
    TaffarelJr.TestRunner's own job, not this script's. This script never
    changes PSModulePath: a test file imports what it tests by path, and a
    test that only passes when a module resolves by name must fail here too.
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

    [ValidateRange('Positive')]
    [int]$ThrottleLimit,

    [ValidateRange(0, 86400)]
    [int]$TimeoutSeconds,

    [switch]$ShowOutput,

    [switch]$Coverage,

    [switch]$Integration
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSCmdlet.ParameterSetName -eq 'Module') {
    # Split apart the same way a comma-joined -Path/-SourceRoot would be -
    # a caller invoked externally (pwsh -File, a CI workflow's own shell
    # step) can only ever bind one bare token per flag to an array
    # parameter, so '-Module Git,Tally' arrives as one element, not two.
    $names = @($Module | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if (-not $names) {
        throw '-Module names no module.'
    }

    foreach ($name in $names) {
        if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot "TaffarelJr.$name") -PathType Container)) {
            throw "-Module '$name' has no test folder: there is no test/TaffarelJr.$name."
        }
    }

    $Path = @($names | ForEach-Object { Join-Path $PSScriptRoot "TaffarelJr.$_" })
    $SourceRoot = @($names | ForEach-Object { Join-Path $PSScriptRoot '..' 'src' "TaffarelJr.$_" })
}

# Imported by path, each after the modules it requires, the same way every
# test file imports what it tests. Putting src/ on PSModulePath instead would
# reach every test process too, and hide a test that only passes because a
# module resolves by name there.
$srcRoot = [Path]::GetFullPath((Join-Path $PSScriptRoot '..' 'src'))
foreach ($name in 'Tally', 'ConsoleOutput', 'ProcessInvocation', 'RequiredModules', 'TestRunner') {
    $manifest = Join-Path -Path $srcRoot -ChildPath "TaffarelJr.$name" -AdditionalChildPath "TaffarelJr.$name.psd1"
    Import-Module -Name $manifest -Force
}

# Only what the caller asked for is passed on, so Invoke-TestRun's own
# defaults stay the one place a default lives.
$options = @{}
foreach ($name in 'ThrottleLimit', 'TimeoutSeconds') {
    if ($PSBoundParameters.ContainsKey($name)) {
        $options[$name] = $PSBoundParameters[$name]
    }
}

# The integration files need the real tool and a login, so they run only when asked for.
if (-not $Integration) {
    $options.Exclude = '*.Live', '*.Contract'
}

$run = Invoke-TestRun `
    -Path $Path `
    -TestRoot $PSScriptRoot `
    -Filter $Filter `
    -Coverage:$Coverage `
    -OutputPath $OutputPath `
    -ResultsPath $ResultsPath `
    -SourceRoot $SourceRoot `
    -ShowOutput:$ShowOutput `
    @options
exit $run.ExitCode
