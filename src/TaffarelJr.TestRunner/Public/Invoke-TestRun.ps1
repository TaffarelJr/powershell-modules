using namespace System.Diagnostics
using namespace System.IO
using namespace System.Text

function Invoke-TestRun {
    <#
    .SYNOPSIS
        Runs every matching test file, with coverage on request, several at
        a time, prints each result as it finishes, and returns the results
        with the exit code to end with: the number of failed files (at most
        255), or 1 when there were no files at all.
    .DESCRIPTION
        A file fails when it exits non-zero, crashes, runs past
        -TimeoutSeconds, or reports a failed case - whatever its exit code
        says. A file whose tally counts no case at all fails too, unless it
        said why: a skipped file (TestKit's Skip-TestRun) shows its reason
        and is counted apart in the summary, and a file whose checks run by
        other means (Complete-TestRun -AllowEmpty) passes with a note saying
        so. A file that cannot
        even be started is reported as not started, with the reason, rather
        than left out of the run.

        Each file runs in a pwsh of its own. Without -Coverage that is the
        whole story: no Pester is loaded, checked or needed, and no report is
        written. With -Coverage each file runs under a wrapper that measures
        the code under -SourceRoot, which costs seconds a file, and writes a
        coverage report and a result report for it; existing reports are
        overwritten file by file, and reports of test files that no longer
        exist are not removed.

        A folder that is not there, a missing prerequisite, or any other
        failure of the run itself is a terminating error for the call. A test
        file that fails is not: it is a result, and the exit code counts it.

        With -Verbose, shows the command line of each test file's process
        before it is started.
    .PARAMETER Path
        One or more folders to search for *.Tests.ps1 files, recursively.
        Narrowing this to one module's folder - or a handful of them - only
        limits the search - it never changes a file's display name or
        where its reports land, so a scoped run and a full run always
        agree on both. A single comma-joined entry ('A,B') is split apart
        the same as a true multi-element array, since a caller invoked
        externally (pwsh -File, a CI workflow's own shell step) can only
        ever bind one bare token per flag to an array parameter. Each entry
        must be an existing folder, not a file. A file found under two of
        the folders runs once.
    .PARAMETER TestRoot
        The folder every file's display name, coverage report,
        and result report are computed relative to.
        Not derived from -Path, for the same reason as -SourceRoot:
        a caller may narrow -Path to one module while running,
        but reports still need to land where a full run would put them.
        Defaults to -Path, so a caller that never narrows -Path
        does not have to pass this separately - only meaningful when
        -Path is exactly one folder; -Path with several requires -TestRoot
        explicitly, since there is no single folder left to default to.
        Every test file has to be under it.
    .PARAMETER SourceRoot
        One or more folders, split apart the same way as -Path. With
        -Coverage, coverage measures them, recursively, test files excluded.
        Each must be an existing folder; that is checked before any file
        runs. Not derived from -Path - a caller's source layout is its own to
        decide (a top-level src/ sibling, a per-subject folder, anything
        else), not this module's to assume. Every file runs with the deepest
        folder holding all of them as its current location; see
        Invoke-TestFileProcess for which root the paths in a coverage report
        are relative to. A test file whose first display-name segment names a
        folder directly under one of these roots is measured over that folder
        alone, so a run over every module measures each module by its own
        tests.
    .PARAMETER Coverage
        Runs every file under the coverage wrapper, which writes one coverage
        report and one result report per file, to -OutputPath and
        -ResultsPath. It needs Pester, which is checked here and installed
        when missing; without -Coverage Pester is never touched and no
        report is written.
    .PARAMETER OutputPath
        Required with -Coverage, unused without it. Where the coverage
        reports go; each file gets its own, mirroring its display name.
    .PARAMETER ResultsPath
        Required with -Coverage, unused without it. Where the JUnit result
        reports go; each file gets its own, mirroring its display name.
    .PARAMETER WrapperPath
        Used only with -Coverage, ignored without it. Handed to
        Invoke-TestFileProcess for every file, made absolute first.
        Defaults to this module's own Scripts/Invoke-TestFile.ps1 -
        override it only for a different Pester configuration.
    .PARAMETER Filter
        A file-system filter over the file name, without the .Tests.ps1
        suffix: * and ? only - brackets are not a character range.
    .PARAMETER Exclude
        Patterns over the file name, without the .Tests.ps1 suffix, in the
        same vocabulary as -Filter: * and ? only, brackets stand for
        themselves, and case does not matter. A file matching any one of them
        is not run. A single comma-joined entry ('*.Live,*.Contract') is
        split apart the same as -Path is, since a caller invoked externally
        can only ever bind one bare token per flag.
    .PARAMETER ThrottleLimit
        How many files run at once. Defaults to the processor count; each
        file is its own process - a fresh pwsh, under its own coverage
        wrapper with -Coverage - so the limit is about the machine, not
        isolation: contention for its CPU and disk is the only cost of
        running several at a time, and a machine whose disk is the
        bottleneck may want fewer.
    .PARAMETER TimeoutSeconds
        How long one file may run before it is stopped and counted as crashed,
        along with any process it started that still holds its output open.
        0, the default, waits as long as it takes - a file that never ends
        then never lets the run end either.
    .PARAMETER ShowOutput
        Prints every file's captured output, not just a failing file's.
    .INPUTS
        None. Nothing can be piped in.
    .OUTPUTS
        System.Management.Automation.PSCustomObject. Results, one result per
        test file (see Invoke-TestFileProcess), and ExitCode, the number the
        run should end with.
    .EXAMPLE
        $run = Invoke-TestRun -Path 'test' -SourceRoot 'src'
        exit $run.ExitCode

        Runs every test file under test/ on its own, with no coverage and no
        reports, and ends the script with the run's exit code.
    .EXAMPLE
        Invoke-TestRun -Path 'test/TaffarelJr.Tally' -TestRoot 'test' `
            -SourceRoot 'src/TaffarelJr.Tally' -Coverage `
            -OutputPath 'test/coverage' -ResultsPath 'test/results'

        Runs one module's tests only, under coverage. -TestRoot stays at the
        real root, so the display names and the report paths are the ones a
        full run uses.
    .EXAMPLE
        Invoke-TestRun -Path 'test' -SourceRoot 'src' `
            -Exclude '*.Live', '*.Contract'

        Runs every test file except the integration ones, which are named
        *.Live.Tests.ps1 and *.Contract.Tests.ps1.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestRunner/README.md
    .LINK
        Invoke-TestFileProcess
    .LINK
        Import-LocalModule
    .NOTES
        Results print in whichever order files finish, not the order
        Find-TestFile discovered them in - an inherent trade-off of running
        more than one at a time.

        With -Coverage, Pester 5.3.0 or later is the one prerequisite every
        caller needs regardless of its own layout, so it's checked here,
        once, rather than leaving every caller to declare it in a manifest of
        their own - installing it from several child processes at once would
        race. A missing or older Pester is installed without asking, for the
        current user, through Assert-RequiredModule.
        A Pester already loaded in this session - even one imported by its
        path - is the one every file runs under.
        Without -Coverage none of this happens.

        The console encoding is also set to UTF-8 for the length of the run,
        then put back - without it, a Windows console decodes this module's
        own ✅/❌ markers as its legacy code page instead of the UTF-8
        they actually are.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path,

        [string]$TestRoot,

        [Parameter(Mandatory)]
        [string[]]$SourceRoot,

        [switch]$Coverage,

        [string]$OutputPath,

        [string]$ResultsPath,

        [string]$WrapperPath = (
            Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'Scripts', 'Invoke-TestFile.ps1'
        ),

        [string]$Filter = '*',

        [string[]]$Exclude = @(),

        [ValidateRange('Positive')]
        [int]$ThrottleLimit = [Environment]::ProcessorCount,

        [ValidateRange(0, 86400)]
        [int]$TimeoutSeconds,

        [switch]$ShowOutput
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $verboseRequested = $VerbosePreference -eq 'Continue'

        if ($Coverage -and (-not $OutputPath -or -not $ResultsPath)) {
            throw '-Coverage needs -OutputPath and -ResultsPath.'
        }

        $Path = @(Expand-PathList -Value $Path)
        $SourceRoot = @(Expand-PathList -Value $SourceRoot)
        $Exclude = @(Expand-PathList -Value $Exclude)

        if ($Path.Count -eq 0) {
            throw '-Path names no folder.'
        }

        if ($SourceRoot.Count -eq 0) {
            throw '-SourceRoot names no folder.'
        }

        if (-not $TestRoot) {
            if ($Path.Count -ne 1) {
                throw '-TestRoot is required when -Path names more than one folder.'
            }

            $TestRoot = $Path[0]
        }

        $folders = [ordered]@{
            '-Path'       = $Path
            '-TestRoot'   = @($TestRoot)
            '-SourceRoot' = $SourceRoot
        }
        foreach ($parameter in $folders.Keys) {
            foreach ($folder in $folders[$parameter]) {
                if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
                    throw "$parameter '$folder' is not an existing folder."
                }
            }
        }

        $searchRoot = @((Resolve-Path -LiteralPath $Path).ProviderPath)
        $namingRoot = (Resolve-Path -LiteralPath $TestRoot).ProviderPath
        $sourceRoots = @((Resolve-Path -LiteralPath $SourceRoot).ProviderPath)

        $coverageRequested = $Coverage.IsPresent
        $wrapper = $null
        $pesterPath = $null
        if ($Coverage) {
            $wrapper = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WrapperPath)

            Assert-RequiredModule -Data @{
                Pester = @{
                    MinimumVersion   = '5.3.0'
                    DocumentationUrl = 'https://pester.dev'
                }
            }

            $pesterPath = Get-LoadedPesterPath
        }

        $previousEncoding = $null
        try {
            $original = [Console]::OutputEncoding
            Set-ConsoleEncoding -Encoding ([UTF8Encoding]::new($false))
            $previousEncoding = $original
        }
        catch [IOException] {
            Write-Verbose 'No console to set the output encoding of; it is left as it is.'
        }

        try {
            $files = @(Find-TestFile -Path $searchRoot -Filter $Filter -Exclude $Exclude)
            if (-not $files) {
                $where = $searchRoot -join ', '
                $excluding = if ($Exclude) { ", after excluding $($Exclude -join ', ')" }
                Write-Warn "No test file matches '$Filter.Tests.ps1' under $where$excluding"
                return [PSCustomObject]@{
                    Results  = @()
                    ExitCode = 1
                }
            }

            $reportRoot = $null
            $resultRoot = $null
            if ($Coverage) {
                $reportRoot = (New-Item -ItemType Directory -Force -Path $OutputPath).FullName
                $resultRoot = (New-Item -ItemType Directory -Force -Path $ResultsPath).FullName
            }

            $items = foreach ($file in $files) {
                $name = Get-TestDisplayName -TestRoot $namingRoot -File $file.FullName
                $roots = $sourceRoots
                $reportPath = $null
                $resultPath = $null
                if ($Coverage) {
                    $roots = @(Get-FileSourceRoot -Name $name -SourceRoot $sourceRoots)
                    $reportPath = Get-CoverageReportPath -OutputPath $reportRoot -Name $name
                    $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportPath)
                    $resultPath = Get-TestResultPath -OutputPath $resultRoot -Name $name
                    $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resultPath)
                }

                [PSCustomObject]@{
                    File       = $file.FullName
                    Name       = $name
                    SourceRoot = $roots
                    ReportPath = $reportPath
                    ResultPath = $resultPath
                }
            }

            Write-Detail "Running $($files.Count) test file(s), up to $ThrottleLimit at a time"

            # ForEach-Object -Parallel runspaces start clean - they don't inherit
            # this runspace's already-loaded modules, only $using: variables - so
            # each worker imports what it needs by the exact path that got it
            # loaded here in the first place. That works whether this module was
            # dot-loaded from a repo's own src/ folder or installed from the
            # Gallery, without this function having to guess which layout it's
            # running under.
            $modulePaths = @(Get-WorkerModulePath)

            # A worker's own failure is a result too: an error there would only be
            # written to the error stream, and the file would silently drop out.
            $total = [Stopwatch]::StartNew()
            $results = $items | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
                $item = $_
                try {
                    # A pooled runspace is reused for the next file, and importing
                    # all over again costs seconds a file.
                    foreach ($modulePath in $using:modulePaths) {
                        $loaded = Get-Module | Where-Object { $_.Path -eq $modulePath }
                        if (-not $loaded) {
                            Import-Module $modulePath -ErrorAction Stop
                        }
                    }

                    $call = @{
                        File           = $item.File
                        Name           = $item.Name
                        SourceRoot     = $item.SourceRoot
                        TimeoutSeconds = $using:TimeoutSeconds
                        Verbose        = $using:verboseRequested
                    }
                    if ($using:coverageRequested) {
                        $call.Coverage = $true
                        $call.ReportPath = $item.ReportPath
                        $call.ResultPath = $item.ResultPath
                        $call.WrapperPath = $using:wrapper
                        $call.PesterPath = $using:pesterPath
                    }

                    $result = Invoke-TestFileProcess @call
                    [PSCustomObject]@{
                        Item    = $item
                        Result  = $result
                        Failure = $null
                    }
                }
                catch {
                    [PSCustomObject]@{
                        Item    = $item
                        Result  = $null
                        Failure = $_.Exception.Message
                    }
                }
            } | ForEach-Object {
                $result = $_.Result
                if (-not $result) {
                    $result = New-TestFileResult `
                        -Name $_.Item.Name `
                        -Crashed `
                        -NotStarted `
                        -ExitCode 127 `
                        -Output @($_.Failure)
                }

                Write-TestResult -Result $result -ShowOutput:$ShowOutput
                $result
            }
            $total.Stop()

            $failedFiles = @($results | Where-Object { Test-FileFailed -Result $_ })
            $summary = Format-TestSummary -Results @($results) -Elapsed $total.Elapsed
            if ($failedFiles) {
                Write-Failure $summary
            }
            else {
                Write-Success $summary
            }

            if ($Coverage) {
                Write-Detail "Coverage reports in $reportRoot"
                Write-Detail "Test results in $resultRoot"
            }
            else {
                Write-Detail 'No coverage or result reports were written: pass -Coverage for them.'
            }

            return [PSCustomObject]@{
                Results  = @($results)
                ExitCode = Get-RunExitCode -FailedCount $failedFiles.Count
            }
        }
        finally {
            if ($previousEncoding) {
                [Console]::OutputEncoding = $previousEncoding
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
