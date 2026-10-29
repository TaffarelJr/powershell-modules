using namespace System.Diagnostics
using namespace System.IO
using namespace System.Management.Automation.Language

function Invoke-TestFileProcess {
    <#
    .SYNOPSIS
        Runs one test file in a fresh pwsh on its own, or with -Coverage
        under a coverage wrapper script, and returns its result: name,
        tally, exit code, time, and captured output.
    .DESCRIPTION
        The spawn itself goes through Invoke-NativeRead: a crashing or
        failing test file is an ordinary, survivable result here, not an
        error this function should throw on - exactly the case
        Invoke-NativeRead exists for.

        Without -Coverage the process is pwsh -File on the test file, with
        no wrapper and no Pester: the file is the script scope of a process
        of its own. The file is read here first, and one that does not
        parse, or has no exit statement anywhere, is not run: it counts as
        crashed with exit code 1, and its output is one line per parse error
        (file, line, column and message), or the sentence saying the exit is
        missing. A file that cannot be read is reported like a parse error.
        The file's error stream reaches the result after its standard
        output, since Invoke-NativeRead appends it, and the tally is the
        last line holding both counts, so text after it does not hide it.

        With -Coverage the file runs under the wrapper script, which writes
        the coverage and result reports. The wrapper runs the file in a scope
        of its own, with strict mode off, information messages always shown,
        and each output object formatted on its own; see its own help.

        The child starts in the deepest existing folder that holds every
        -SourceRoot folder, so the paths in a coverage report do not depend
        on where the run was started; roots that share no folder at all leave
        it in this process's working directory. A narrower -SourceRoot, such
        as the one folder Invoke-TestRun hands over for a file it measures
        by module, moves the working directory with it.
        Pester 6 makes them relative to the git repository holding that
        folder, or to the folder itself when there is none; Pester 5 makes
        them relative to the deepest folder holding every file it measured.
        Every path handed to the wrapper is made absolute first, against
        PowerShell's current location.

        A file that does not finish within -TimeoutSeconds is stopped and
        counts as crashed, with TimedOut set. That includes a process the
        file started that still holds its output open after the file ended.
        A process that could not be started at all counts as crashed too,
        with NotStarted set.

        A -SourceRoot that cannot cross into the process is a terminating
        error for the call, raised before anything is started, with or
        without -Coverage so that a run is accepted or refused the same way
        either way. So is -Coverage without both report paths.

        With -Verbose, shows the command line of the process before it is
        started.
    .PARAMETER File
        The *.Tests.ps1 to run.
    .PARAMETER Name
        The display name to attach to the result.
    .PARAMETER SourceRoot
        One or more folders. The file starts in the deepest one holding all
        of them; with -Coverage, coverage measures them too, joined with the
        platform path separator before being passed to the wrapper - a child
        process started from an argument array only ever binds the first
        bare value following a flag to a [string[]] parameter, silently
        dropping the rest, so the list has to cross that boundary as one
        delimited string instead. A folder whose own path contains that
        separator cannot cross it, and is refused.
    .PARAMETER Coverage
        Runs the file under the coverage wrapper, which needs Pester and
        writes a Cobertura report to -ReportPath and a JUnit result to
        -ResultPath. Without it the file runs on its own and nothing is
        written.
    .PARAMETER ReportPath
        Required with -Coverage, unused without it. Handed to the wrapper as
        -OutputPath, made absolute first.
    .PARAMETER ResultPath
        Required with -Coverage, unused without it. Handed to the wrapper as
        -ResultPath, made absolute first.
    .PARAMETER WrapperPath
        Used only with -Coverage, ignored without it. The script to spawn - it
        decides how the file actually runs under coverage (this module makes
        no assumption about that mechanism).
        It must accept -TestFile, -SourceRoot, -OutputPath, and -ResultPath,
        and exit with the test file's own exit code.
        Defaults to this module's own Scripts/Invoke-TestFile.ps1 -
        override it only for a different Pester configuration.
    .PARAMETER PesterPath
        Used only with -Coverage, ignored without it. The Pester manifest the
        wrapper imports by its path, handed to it in the
        TESTRUNNER_PESTER_PATH environment variable. Defaults to the
        Pester 5.3.0 or later loaded in this session; with none loaded, or
        given as an empty string, the variable is left unset and the wrapper
        imports Pester by name. A file run on its own never has the variable.
    .PARAMETER TimeoutSeconds
        How long the file may run before it is stopped.
        0, the default, waits as long as it takes.
    .INPUTS
        None. Nothing can be piped in.
    .OUTPUTS
        System.Management.Automation.PSCustomObject. The result: Name,
        Passed, Failed, Crashed, TimedOut, NotStarted, Skipped, SkipReason,
        AllowedEmpty, ExitCode, Seconds, and Output.
    .EXAMPLE
        $result = Invoke-TestFileProcess -File 'test/Get-Thing.Tests.ps1' `
            -Name 'Get-Thing' -SourceRoot 'src'

        Runs one file on its own; $result.Output is what it printed.
    .EXAMPLE
        $result = Invoke-TestFileProcess -File 'test/Get-Thing.Tests.ps1' `
            -Name 'Get-Thing' -SourceRoot 'src' -Coverage `
            -ReportPath 'out/Get-Thing.cobertura.xml' `
            -ResultPath 'out/Get-Thing.junit.xml'

        Runs one file under the default coverage wrapper, which writes both
        reports.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.TestRunner/README.md
    .LINK
        Invoke-TestRun
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$File,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string[]]$SourceRoot,

        [switch]$Coverage,

        [string]$ReportPath,

        [string]$ResultPath,

        [string]$WrapperPath = (
            Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'Scripts', 'Invoke-TestFile.ps1'
        ),

        [string]$PesterPath,

        [ValidateRange(0, 86400)]
        [int]$TimeoutSeconds
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        if ($Coverage -and (-not $ReportPath -or -not $ResultPath)) {
            throw '-Coverage needs -ReportPath and -ResultPath.'
        }

        $separator = [Path]::PathSeparator
        foreach ($root in $SourceRoot) {
            if ($root.Contains($separator)) {
                throw "-SourceRoot entry '$root' contains '$separator', which separates the list handed to the wrapper."
            }
        }

        $paths = $ExecutionContext.SessionState.Path
        $sourceRoots = @(
            foreach ($root in $SourceRoot) {
                $paths.GetUnresolvedProviderPathFromPSPath($root)
            }
        )

        $testFile = $paths.GetUnresolvedProviderPathFromPSPath($File)
        if ($Coverage) {
            if (-not $PSBoundParameters.ContainsKey('PesterPath')) {
                $PesterPath = Get-LoadedPesterPath
            }

            $arguments = @(
                '-NoProfile', '-NonInteractive', '-File', $paths.GetUnresolvedProviderPathFromPSPath($WrapperPath)
                '-TestFile', $testFile
                '-SourceRoot', ($sourceRoots -join $separator)
                '-OutputPath', $paths.GetUnresolvedProviderPathFromPSPath($ReportPath)
                '-ResultPath', $paths.GetUnresolvedProviderPathFromPSPath($ResultPath)
            )
            $pesterVariable = if ($PesterPath) { $PesterPath } else { $null }
        }
        else {
            $parseErrors = $null
            $syntax = [Parser]::ParseFile($testFile, [ref]$null, [ref]$parseErrors)
            $exitStatement = $syntax.Find({ param($node) $node -is [ExitStatementAst] }, $true)
            $problems = @(
                foreach ($parseError in $parseErrors) {
                    $line = $parseError.Extent.StartLineNumber
                    $column = $parseError.Extent.StartColumnNumber
                    "${testFile}:${line}:${column}: $($parseError.Message)"
                }
            )
            if ($problems.Count -eq 0 -and -not $exitStatement) {
                $problems = @('The file has no exit statement; it must end with exit (Complete-TestRun).')
            }

            if ($problems.Count -gt 0) {
                return New-TestFileResult -Name $Name -Crashed -ExitCode 1 -Output $problems
            }

            $arguments = @('-NoProfile', '-NonInteractive', '-File', $testFile)
            $pesterVariable = $null
        }

        $pwsh = [Process]::GetCurrentProcess().MainModule.FileName

        # Set or removed, never inherited: a file this run starts may run tests
        # of its own, and those must not pick up this run's Pester by accident.
        $readParameters = @{
            Command     = $pwsh
            Arguments   = $arguments
            Environment = @{ TESTRUNNER_PESTER_PATH = $pesterVariable }
        }

        $workingDirectory = Get-SharedFolder -Path $sourceRoots
        if ($workingDirectory) {
            $readParameters.WorkingDirectory = $workingDirectory
        }

        if ($TimeoutSeconds -gt 0) {
            $readParameters.TimeoutSeconds = $TimeoutSeconds
        }

        Write-Verbose "Running '$Name' in a new process: $pwsh $($arguments -join ' ')"
        $clock = [Stopwatch]::StartNew()
        $read = Invoke-NativeRead @readParameters -Verbose:$false
        $clock.Stop()

        $output = @($read.Output)
        if ($read.TimedOut) {
            $output += "Stopped after $TimeoutSeconds seconds without finishing."
        }

        $tally = Read-TestTally -Output $read.Output -ExitCode $read.ExitCode

        return New-TestFileResult `
            -Name $Name `
            -Passed $tally.Passed `
            -Failed $tally.Failed `
            -Crashed:($tally.Crashed -or $read.TimedOut -or -not $read.Started) `
            -TimedOut:$read.TimedOut `
            -NotStarted:(-not $read.Started) `
            -Skipped:$tally.Skipped `
            -SkipReason $tally.SkipReason `
            -AllowedEmpty:$tally.AllowedEmpty `
            -ExitCode $read.ExitCode `
            -Seconds $clock.Elapsed.TotalSeconds `
            -Output $output
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
