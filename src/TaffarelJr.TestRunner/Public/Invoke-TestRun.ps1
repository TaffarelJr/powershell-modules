using namespace System.Diagnostics
using namespace System.Text

function Invoke-TestRun {
    <#
    .SYNOPSIS
        Runs every matching test file under coverage, several at a time,
        prints each result as it finishes, and returns the results with
        the exit code to end with: the number of failed files, or 1 when
        there were no files at all.
    .PARAMETER Path
        One or more folders to search for *.Tests.ps1 files, recursively.
        Narrowing this to one module's folder - or a handful of them - only
        limits the search - it never changes a file's display name or
        where its reports land, so a scoped run and a full run always
        agree on both. A single comma-joined entry ('A,B') is split apart
        the same as a true multi-element array, since a caller invoked
        externally (pwsh -File, a CI workflow's own shell step) can only
        ever bind one bare token per flag to an array parameter.
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
    .PARAMETER SourceRoot
        One or more folders coverage measures, recursively, test files
        excluded. Not derived from -Path - a caller's source layout is its
        own to decide (a top-level src/ sibling, a per-subject folder,
        anything else), not this module's to assume.
    .PARAMETER OutputPath
        Where the coverage reports go;
        each file gets its own, mirroring its display name.
    .PARAMETER ResultsPath
        Where the JUnit result reports go;
        each file gets its own, mirroring its display name.
    .PARAMETER WrapperPath
        Passed straight through to Invoke-TestFileProcess for every file.
        Defaults to this module's own Scripts/Invoke-TestFile.ps1 -
        override it only for a different Pester configuration.
    .PARAMETER Filter
        A wildcard over the file name, without the .Tests.ps1 suffix.
    .PARAMETER ThrottleLimit
        How many files run at once. Each one is already its own isolated
        process - a fresh pwsh, under its own coverage wrapper - so running
        several at a time costs nothing in isolation, only in contention for
        the machine's own CPU and disk. Defaults to 4; a faster or slower
        machine may want a different number.
    .PARAMETER ShowOutput
        Prints every file's captured output, not just a failing file's.
    .NOTES
        Results print in whichever order files finish, not the order
        Find-TestFile discovered them in - an inherent trade-off of running
        more than one at a time.

        Pester is the one prerequisite every caller needs regardless of its
        own layout, so it's checked here, once, rather than leaving every
        caller to declare it in a manifest of their own - installing it from
        several child processes at once would race.

        The console encoding is also fixed here, once, rather than leaving
        every caller to remember it - without it, a Windows console decodes
        this module's own ▶/✅/❌ markers as its legacy code page instead of
        the UTF-8 they actually are.
    #>
    param(
        [Parameter(Mandatory)][string[]]$Path,
        [string]$TestRoot,
        [Parameter(Mandatory)][string[]]$SourceRoot,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$ResultsPath,
        [string]$WrapperPath = (Join-Path $PSScriptRoot '..' 'Scripts' 'Invoke-TestFile.ps1'),
        [string]$Filter = '*',
        [int]$ThrottleLimit = 4,
        [switch]$ShowOutput
    )

    $Path = Expand-PathList -Value $Path
    $SourceRoot = Expand-PathList -Value $SourceRoot

    if (-not $TestRoot) {
        if ($Path.Count -ne 1) {
            throw '-TestRoot is required when -Path names more than one folder.'
        }

        $TestRoot = $Path[0]
    }

    Assert-RequiredModule -Data @{
        Pester = @{
            MinimumVersion   = '5.0.0'
            DocumentationUrl = 'https://pester.dev'
        }
    }
    [Console]::OutputEncoding = [UTF8Encoding]::new()

    $searchRoot = @((Resolve-Path -LiteralPath $Path).Path)
    $namingRoot = (Resolve-Path -LiteralPath $TestRoot).Path
    $files = Find-TestFile -Path $searchRoot -Filter $Filter
    if (-not $files) {
        Write-Host "No test file matches '$Filter.Tests.ps1' under $($searchRoot -join ', ')" -ForegroundColor Yellow
        return [PSCustomObject]@{
            Results  = @()
            ExitCode = 1
        }
    }

    $reportRoot = (New-Item -ItemType Directory -Force -Path $OutputPath).FullName
    $resultRoot = (New-Item -ItemType Directory -Force -Path $ResultsPath).FullName

    $items = foreach ($file in $files) {
        $name = Get-TestDisplayName -TestRoot $namingRoot -File $file.FullName
        $reportPath = Get-CoverageReportPath -OutputPath $reportRoot -Name $name
        $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportPath)
        $resultPath = Get-TestResultPath -OutputPath $resultRoot -Name $name
        $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resultPath)

        [PSCustomObject]@{
            File       = $file.FullName
            Name       = $name
            ReportPath = $reportPath
            ResultPath = $resultPath
        }
    }

    # ForEach-Object -Parallel runspaces start clean - they don't inherit
    # this runspace's already-loaded modules, only $using: variables - so
    # each worker re-imports every TaffarelJr.* module already loaded here,
    # by the exact path that got it loaded in the first place. That works
    # whether this module was dot-loaded from a repo's own src/ folder or
    # installed from the Gallery, without this function having to guess
    # which layout it's running under.
    $modulePaths = @(Get-Module -Name 'TaffarelJr.*' | Select-Object -ExpandProperty Path)

    $total = [Stopwatch]::StartNew()
    $results = $items | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        foreach ($modulePath in $using:modulePaths) {
            Import-Module $modulePath -Force
        }

        Invoke-TestFileProcess `
            -File $_.File `
            -Name $_.Name `
            -SourceRoot $using:SourceRoot `
            -ReportPath $_.ReportPath `
            -ResultPath $_.ResultPath `
            -WrapperPath $using:WrapperPath
    } | ForEach-Object {
        Write-Host "▶ $($_.Name) ..." -NoNewline -ForegroundColor Cyan
        if ($ShowOutput) { Write-Host '' }
        Write-TestResult -Result $_ -ShowOutput:$ShowOutput
        $_
    }
    $total.Stop()

    $failedFiles = @($results | Where-Object { Test-FileFailed -Result $_ })
    $color = if ($failedFiles) { 'Red' } else { 'Green' }
    $summary = Format-TestSummary -Results @($results) -Elapsed $total.Elapsed
    Write-Host ''
    Write-Host $summary -ForegroundColor $color
    Write-Detail "Coverage reports in $reportRoot"
    Write-Detail "Test results in $resultRoot"

    return [PSCustomObject]@{
        Results  = @($results)
        ExitCode = $failedFiles.Count
    }
}
