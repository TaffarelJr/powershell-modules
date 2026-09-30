#Requires -Version 7.4

<#
.SYNOPSIS
    Runs one test file under Pester's coverage tracer,
    writes its Cobertura report, and exits with the file's own exit code.
    This is Invoke-TestRun's own default -WrapperPath -
    override it only for a different Pester configuration.

.DESCRIPTION
    Pester is only the coverage collector and the JUnit exporter.
    The file runs as-is inside one It block, in a scope of its own that
    starts with strict mode off and $ErrorActionPreference at Continue.
    Run on its own, a file is the global scope; here that scope sits below
    this wrapper's and Pester's, so the file can read their variables, and
    the functions of the modules it imports run with this wrapper's global
    $ErrorActionPreference, Stop - what a test file that sets Stop for
    itself gives them when it runs on its own.

    Everything it writes - the pipeline, errors, warnings, verbose, debug
    and information messages, and host output - is printed on stdout in the
    order it was written, so its assertions and its tally line reach
    Invoke-TestFileProcess untouched and in order.
    Pester's own output is off so nothing else lands in between.
    Information messages are shown whatever $InformationPreference says,
    and each output object is formatted on its own.

    A file must end by calling exit: its exit code is how its failures
    reach the run. A file that does not parse is not run: the parser's
    errors are printed, each with its file, line and column, and it counts
    as crashed. A file with no exit statement anywhere is not run at all
    and counts as crashed, and so does a file that ends without reaching
    one - unless a native command it ran left an exit code behind, which is
    then taken as the file's own, and its tally decides.

    -SourceRoot is for coverage only - this wrapper never imports anything
    under it itself. A test file imports what it needs itself (see
    Import-LocalModule); the alternative, importing
    everything under -SourceRoot for every single file, would load modules
    a given file never asked for, for every file in an entire run.

    The It block itself throws whenever the file exits non-zero, not just
    when running it throws outright - otherwise every file reports as
    "passed" in Pester's own verdict (and so in the JUnit report) purely
    because running it didn't itself raise an exception, regardless of
    how many of its own assertions actually failed.

    Pester is assumed already installed - a caller checks that once,
    up front, rather than every child process repeating the check. The
    TESTRUNNER_PESTER_PATH environment variable, when set, names the Pester
    manifest to import by its path, so the child uses the very Pester its
    caller resolved, even one that is not on PSModulePath; otherwise Pester
    is imported by name. Either way it must be 5.3.0 or later.

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
using namespace System.Management.Automation
using namespace System.Management.Automation.Language

# The container's parameters are used inside its nested It block, where the
# analyzer does not look; $State is how the exit code leaves it.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'State')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'HasExit')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ParseProblem')]
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost',
    '',
    Justification = 'Reports a test run to the person at the console; it is not data.')]
param(
    [Parameter(Mandatory)]
    [string]$TestFile,

    [Parameter(Mandatory)]
    [string]$SourceRoot,

    [Parameter(Mandatory)]
    [string]$OutputPath,

    [Parameter(Mandatory)]
    [string]$ResultPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceRootPaths = $SourceRoot -split [regex]::Escape([Path]::PathSeparator)

# 5.3.0 added CodeCoverage.UseBreakpoints, set below.
$minimumPester = [version]'5.3.0'
$pesterPath = $env:TESTRUNNER_PESTER_PATH
if ($pesterPath) {
    if (-not (Test-Path -LiteralPath $pesterPath -PathType Leaf)) {
        throw "TESTRUNNER_PESTER_PATH names no file: '$pesterPath'."
    }

    $available = Get-Module -ListAvailable -Name $pesterPath
    if ($available.Version -lt $minimumPester) {
        throw "Pester $($available.Version) at '$pesterPath' is older than $minimumPester, which this wrapper needs."
    }

    $pester = Import-Module -Name $pesterPath -Force -PassThru
}
else {
    $pester = Import-Module -Name Pester -MinimumVersion $minimumPester -Force -PassThru
}

$parseErrors = $null
$syntax = [Parser]::ParseFile($TestFile, [ref]$null, [ref]$parseErrors)
$exitStatement = $syntax.Find({ param($node) $node -is [ExitStatementAst] }, $true)
$parseProblem = $null
if ($parseErrors) {
    $problems = foreach ($parseError in $parseErrors) {
        $extent = $parseError.Extent
        "$($extent.File):$($extent.StartLineNumber):$($extent.StartColumnNumber): $($parseError.Message)"
    }
    $parseProblem = (@('The file does not parse:') + $problems) -join [Environment]::NewLine
}

$state = @{ ExitCode = 1 } # Stays 1 - crashed - unless the file reaches its own exit.

$container = New-PesterContainer -Data @{
    TestFile     = $TestFile
    State        = $state
    HasExit      = $null -ne $exitStatement
    ParseProblem = $parseProblem
} -ScriptBlock {
    param([string]$TestFile, [hashtable]$State, [bool]$HasExit, [string]$ParseProblem)

    Describe $TestFile {
        It 'runs to its own exit' {
            # A syntax error can swallow the rest of the file, its exit
            # included, so it is reported before the exit is looked for.
            if ($ParseProblem) {
                throw $ParseProblem
            }

            if (-not $HasExit) {
                throw 'The file never calls exit - end it with: exit (Complete-TestRun)'
            }

            # Unset, so a code left by some command the file ran is not mistaken
            # for the file's own exit when it falls off its end before any.
            $global:LASTEXITCODE = $null
            & {
                Set-StrictMode -Off
                $ErrorActionPreference = 'Continue'
                & $TestFile *>&1 | ForEach-Object {
                    $record = $_
                    if ($record -is [InformationRecord] -and $record.MessageData -is [HostInformationMessage]) {
                        $message = $record.MessageData
                        $hostParameters = @{
                            Object    = $message.Message
                            NoNewline = $message.NoNewLine
                        }
                        if ($null -ne $message.ForegroundColor) {
                            $hostParameters.ForegroundColor = $message.ForegroundColor
                        }

                        Write-Host @hostParameters
                    }
                    elseif ($record -is [InformationRecord]) {
                        Write-Host "$($record.MessageData)"
                    }
                    elseif ($record -is [ErrorRecord]) {
                        $activity = $record.CategoryInfo.Activity
                        $text = $record.Exception.Message
                        if ($activity) {
                            $text = "${activity}: $text"
                        }

                        Write-Host $text
                    }
                    elseif ($record -is [WarningRecord]) {
                        Write-Host "WARNING: $($record.Message)"
                    }
                    elseif ($record -is [VerboseRecord]) {
                        Write-Host "VERBOSE: $($record.Message)"
                    }
                    elseif ($record -is [DebugRecord]) {
                        Write-Host "DEBUG: $($record.Message)"
                    }
                    else {
                        $lines = $record | Out-String -Stream
                        foreach ($line in $lines) {
                            Write-Host $line
                        }
                    }
                }
            }

            $exitCode = $global:LASTEXITCODE
            if ($null -eq $exitCode) {
                throw 'The file ended without calling exit - end it with: exit (Complete-TestRun)'
            }

            $State.ExitCode = $exitCode
            if ($exitCode -ne 0) {
                throw "Exited with code $exitCode - see the file's own captured output for which case(s) failed."
            }
        }
    }
}

$configuration = New-PesterConfiguration
$configuration.Run.Container = $container
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'None'
$configuration.CodeCoverage.Enabled = $true
# Pester reads each coverage path as a wildcard, as it does the result path
# below, so a [ or ] in a source folder's name is escaped.
$escapedSourceRoots = @($sourceRootPaths | ForEach-Object { [WildcardPattern]::Escape($_) })
$configuration.CodeCoverage.Path = $escapedSourceRoots
$configuration.CodeCoverage.ExcludeTests = $true
$configuration.CodeCoverage.OutputFormat = 'Cobertura'
$configuration.CodeCoverage.OutputPath = $OutputPath
# Breakpoints need a debugger, which a -NonInteractive host does not have.
$configuration.CodeCoverage.UseBreakpoints = $false
# A test file uses neither, and TestRegistry would write a registry key for
# every file.
$configuration.TestDrive.Enabled = $false
$configuration.TestRegistry.Enabled = $false
$configuration.TestResult.Enabled = $true
$configuration.TestResult.OutputFormat = 'JUnitXml'
# Pester reads the result path as a wildcard, so a [ or ] in it would stop the
# report being written: Pester writes it under a plain name, moved into place.
$pesterResultPath = Join-Path ([Path]::GetTempPath()) "testrunner-$([Guid]::NewGuid()).junit.xml"
$configuration.TestResult.OutputPath = $pesterResultPath

try {
    $run = Invoke-Pester -Configuration $configuration

    # The report is a by-product: a file's result is its own exit code, so a
    # report that cannot be written is said, not made a crash.
    if (Test-Path -LiteralPath $pesterResultPath) {
        try {
            $resultFullPath = [Path]::GetFullPath($ResultPath)
            $null = [Directory]::CreateDirectory([Path]::GetDirectoryName($resultFullPath))
            [File]::Move($pesterResultPath, $resultFullPath, $true)
        }
        catch {
            $reason = $_.Exception.GetBaseException().Message.TrimEnd('.')
            Write-Host ("Could not write the JUnit result to '$ResultPath': $reason. " +
                'An older report may still be at that path.')
        }
    }
}
finally {
    Remove-Item -LiteralPath $pesterResultPath -Force -ErrorAction Ignore
}

# Pester reports a failure of its own - a coverage path it cannot resolve, a
# report it cannot write - and returns nothing instead of throwing.
if ($null -eq $run) {
    Write-Host 'Pester did not finish the run - see its own error in this output; the file''s result is unknown.'
    exit 1
}

# With Pester's output off, a crash inside the file would otherwise vanish.
# Only the file's own frames are printed: Pester's and this wrapper's say
# nothing about the file.
foreach ($test in $run.Failed) {
    foreach ($record in $test.ErrorRecord) {
        Write-Host $record.Exception.Message
        foreach ($frame in $record.ScriptStackTrace -split '\r?\n') {
            $isOwn = -not $frame -or
                $frame.Contains($pester.ModuleBase) -or
                $frame.Contains($PSCommandPath) -or
                $frame.Contains('<No file>')
            if (-not $isOwn) {
                Write-Host $frame
            }
        }
    }
}

exit $state.ExitCode
