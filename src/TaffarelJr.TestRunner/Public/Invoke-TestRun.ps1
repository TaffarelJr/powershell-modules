using namespace System.Diagnostics

function Invoke-TestRun {
    <#
    .SYNOPSIS
        Runs every matching test file under coverage,
        prints each result and the summary,
        and returns the results with the exit code to end with:
        the number of failed files, or 1 when there were no files at all.
    .PARAMETER Path
        The folder to search for *.Tests.ps1 files, recursively.
    .PARAMETER SourceRoot
        The folder coverage measures, recursively, test files excluded.
        Not derived from -Path - a caller's source layout is its own to decide
        (a top-level src/ sibling, a per-subject folder, anything else),
        not this module's to assume.
    .PARAMETER OutputPath
        Where the coverage reports go;
        each file gets its own, mirroring its display name.
    .PARAMETER ResultsPath
        Where the JUnit result reports go;
        each file gets its own, mirroring its display name.
    .PARAMETER WrapperPath
        Passed straight through to Invoke-TestFileProcess for every file.
    .PARAMETER Filter
        A wildcard over the file name, without the .Tests.ps1 suffix.
    .PARAMETER ShowOutput
        Prints every file's captured output, not just a failing file's.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$OutputPath,
        [Parameter(Mandatory)][string]$ResultsPath,
        [Parameter(Mandatory)][string]$WrapperPath,
        [string]$Filter = '*',
        [switch]$ShowOutput
    )

    $testRoot = (Resolve-Path -LiteralPath $Path).Path
    $files = Find-TestFile -Path $testRoot -Filter $Filter
    if (-not $files) {
        Write-Host "No test file matches '$Filter.Tests.ps1' under $testRoot" -ForegroundColor Yellow
        return [pscustomobject]@{
            Results  = @()
            ExitCode = 1
        }
    }

    $reportRoot = (New-Item -ItemType Directory -Force -Path $OutputPath).FullName
    $resultRoot = (New-Item -ItemType Directory -Force -Path $ResultsPath).FullName

    $total = [Stopwatch]::StartNew()
    $results = foreach ($file in $files) {
        $name = Get-TestDisplayName -TestRoot $testRoot -File $file.FullName
        $reportPath = Get-CoverageReportPath -OutputPath $reportRoot -Name $name
        $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportPath)
        $resultPath = Get-TestResultPath -OutputPath $resultRoot -Name $name
        $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resultPath)

        Write-Host "▶ $name ..." -NoNewline -ForegroundColor Cyan
        if ($ShowOutput) { Write-Host '' }

        $result = Invoke-TestFileProcess `
            -File $file.FullName `
            -Name $name `
            -SourceRoot $SourceRoot `
            -ReportPath $reportPath `
            -ResultPath $resultPath `
            -WrapperPath $WrapperPath
        Write-TestResult -Result $result -ShowOutput:$ShowOutput
        $result
    }
    $total.Stop()

    $failedFiles = @($results | Where-Object { Test-FileFailed -Result $_ })
    $color = if ($failedFiles) { 'Red' } else { 'Green' }
    $summary = Format-TestSummary -Results @($results) -Elapsed $total.Elapsed
    Write-Host ''
    Write-Host $summary -ForegroundColor $color
    Write-Detail "Coverage reports in $reportRoot"
    Write-Detail "Test results in $resultRoot"

    return [pscustomobject]@{
        Results  = @($results)
        ExitCode = $failedFiles.Count
    }
}
