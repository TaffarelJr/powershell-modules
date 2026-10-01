using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Diagnostics
using namespace System.IO
using namespace System.Text
using namespace System.Threading.Tasks

function Invoke-NativeProcess {
    <#
    .SYNOPSIS
        Runs an executable directly, as its own process, and returns its exit
        code and output.
    .DESCRIPTION
        Not exported. The path Invoke-NativeCapture takes when a call needs
        what PowerShell's call operator cannot give: a timeout the process
        can be killed on, or an environment that belongs to the child alone.
        The program is started through System.Diagnostics.Process, so it must
        be an executable - a PowerShell function, alias, or script is not
        supported here.

        Output is read as UTF-8. A child that encodes to the console's code
        page writes UTF-8 only while the console is pinned to it, which is
        Invoke-NativeCapture's job: this function leaves the console alone.
        Stdout and stderr stay separate pipes: when they are merged, all of
        stdout comes first, then all of stderr, where the call operator
        would interleave them as they arrived.

        The wait happens in short slices, so stopping the pipeline - Ctrl+C,
        say - lands within a moment, and a process still running then is
        killed rather than left behind.

        The timeout covers the whole call: writing -StdIn, the process
        itself, and reading its output to the end, which a process it
        started can hold open after it exits. At the deadline the process is
        killed along with the processes it started, and the output read so
        far is kept.
    .PARAMETER Command
        The executable, by name on PATH or by path. Never a pattern: one
        holding a wildcard character must be the path of a file with exactly
        that name.
    .PARAMETER Arguments
        One element per argument.
    .PARAMETER StdIn
        Written to the process, ended with one newline, and closed. A process
        that exits without reading it all is not a failure. Omit it and the
        process gets an input that is already at its end, so a tool that
        asks a question reads no answer instead of waiting on the console.
    .PARAMETER WorkingDirectory
        The directory to start in. It must exist. A relative one is relative to
        PowerShell's current location, which is also where the process starts
        when this is left out.
    .PARAMETER Environment
        Variables set for the child alone, over a copy of this process's. A
        $null value removes one. A name that is empty, blank, or contains
        '=' cannot be a variable's and is refused with a throw.
    .PARAMETER TimeoutSeconds
        How long the whole call may take before the process is killed. Zero
        waits for ever.
    .PARAMETER SeparateStderr
        Keeps stderr out of Output and returns it as ErrorOutput.
    .PARAMETER Program
        The full path of the executable, when the caller has already looked
        Command up: it is run as it is, and Command is not looked up again,
        which costs tens of milliseconds.
    .PARAMETER KillGraceMilliseconds
        How long a killed process is given to close its output pipes before
        the slow search for the processes it started, and then before the
        call gives up on the output still held open.
    .OUTPUTS
        A hashtable: Started, ExitCode, Output, ErrorOutput, and TimedOut. A
        process that could not be started has Started $false, ExitCode 127,
        and the reason, with any credential a URL in it carries hidden, as
        Output; a timed-out one has TimedOut $true and ExitCode 124, the
        code GNU timeout uses.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingEmptyCatchBlock',
        '',
        Justification = 'A process may exit without reading all of its input; that is not a failure.')]
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Arguments = @(),

        [string]$StdIn,

        [string]$WorkingDirectory,

        [IDictionary]$Environment,

        [int]$TimeoutSeconds,

        [switch]$SeparateStderr,

        [string]$Program,

        [ValidateRange('NonNegative')]
        [int]$KillGraceMilliseconds = 2000
    )

    # PSBase: a variable named Keys would otherwise be read in place of every
    # name, here and below.
    if ($Environment) {
        foreach ($name in $Environment.PSBase.Keys) {
            if ("$name" -notmatch '\S' -or "$name".Contains('=')) {
                throw "-Environment name '$(Hide-UrlCredential -Text "$name")' is not a valid variable name:" +
                " it must not be empty, blank, or contain '='."
            }
        }
    }

    $notStarted = {
        param([string]$Reason)
        return @{
            Started     = $false
            ExitCode    = 127
            Output      = [string[]]@(Hide-UrlCredential -Text $Reason)
            ErrorOutput = [string[]]@()
            TimedOut    = $false
        }
    }

    $path = $Program
    if (-not $path) {
        $found = Find-NativeCommand -Command $Command -ApplicationOnly
        if (-not $found) {
            return & $notStarted "'$Command' is not an executable on PATH, and not the path to one."
        }

        $path = $found.Source
    }

    $utf8 = [UTF8Encoding]::new($false)
    $info = [ProcessStartInfo]::new($path)
    foreach ($argument in $Arguments) {
        $info.ArgumentList.Add($argument)
    }

    $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardInputEncoding = $utf8
    $info.StandardOutputEncoding = $utf8
    $info.StandardErrorEncoding = $utf8

    # A Process starts in this process's own directory, which Set-Location does
    # not change, so the directory is always set: to the caller's location, where
    # the call operator would run it, with a relative -WorkingDirectory made
    # absolute against that location first.
    $info.WorkingDirectory = if ($WorkingDirectory) {
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkingDirectory)
    }
    else {
        (Get-Location -PSProvider FileSystem).ProviderPath
    }

    if ($Environment) {
        foreach ($name in $Environment.PSBase.Keys) {
            if ($null -eq $Environment[$name]) {
                $null = $info.Environment.Remove("$name")
            }
            else {
                $info.Environment["$name"] = "$($Environment[$name])"
            }
        }
    }

    try {
        $process = [Process]::Start($info)
    }
    catch {
        return & $notStarted $_.Exception.Message
    }

    try {
        $clock = [Stopwatch]::StartNew()
        $deadline = if ($TimeoutSeconds -gt 0) { $TimeoutSeconds * 1000L } else { [long]::MaxValue }
        $timedOut = $false
        $treeStopped = $false
        $exited = $process.WaitForExitAsync()
        $readers = foreach ($stream in $process.StandardOutput, $process.StandardError) {
            $buffer = [char[]]::new(8192)
            [PSCustomObject]@{
                Stream  = $stream
                Buffer  = $buffer
                Text    = [StringBuilder]::new()
                Pending = $stream.ReadAsync($buffer, 0, $buffer.Length)
            }
        }

        $writing = $null
        if ($PSBoundParameters.ContainsKey('StdIn')) {
            $writing = $process.StandardInput.WriteAsync($StdIn + [Environment]::NewLine)
        }
        else {
            $process.StandardInput.Close()
        }

        while ($true) {
            foreach ($reader in $readers) {
                while ($null -ne $reader.Pending -and $reader.Pending.IsCompleted) {
                    $count = $reader.Pending.Result
                    if ($count -eq 0) {
                        $reader.Pending = $null
                    }
                    else {
                        $null = $reader.Text.Append($reader.Buffer, 0, $count)
                        $reader.Pending = $reader.Stream.ReadAsync($reader.Buffer, 0, $reader.Buffer.Length)
                    }
                }
            }

            if ($null -ne $writing -and $writing.IsCompleted) {
                $writing = $null
                try {
                    $process.StandardInput.Close()
                }
                catch [IOException] {
                    # The process exited without reading all of its input,
                    # which it is entitled to do.
                }
            }

            $pending = [List[Task]]::new()
            foreach ($task in $readers[0].Pending, $readers[1].Pending, $exited, $writing) {
                if ($null -ne $task -and -not $task.IsCompleted) {
                    $pending.Add($task)
                }
            }

            $finished = $null -eq $readers[0].Pending -and $null -eq $readers[1].Pending -and $exited.IsCompleted
            if ($finished -and $null -eq $writing) {
                break
            }

            if ($clock.ElapsedMilliseconds -ge $deadline) {
                # Killing closes the pipes, so a short grace collects what was
                # still in them. Only a pipe still open after it is worth the
                # slow search for processes the kill could not reach, and one
                # open even after that is given up on.
                if (-not $timedOut) {
                    $timedOut = $true
                    $process.Kill($true)
                }
                elseif (-not $treeStopped) {
                    $treeStopped = $true
                    Stop-NativeProcessTree -Process $process
                }
                else {
                    break
                }

                $deadline = $clock.ElapsedMilliseconds + $KillGraceMilliseconds
                continue
            }

            if ($pending.Count -gt 0) {
                $null = [Task]::WaitAny($pending.ToArray(), 200)
            }
        }

        $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
    }
    finally {
        if (-not $process.HasExited) {
            $process.Kill($true)
        }

        $process.Dispose()
    }

    $outputLines = [List[string]]::new()
    $errorLines = [List[string]]::new()
    foreach ($line in [regex]::Split($readers[0].Text.ToString(), '\r\n|\r|\n')) {
        $outputLines.Add($line)
    }

    foreach ($line in [regex]::Split($readers[1].Text.ToString(), '\r\n|\r|\n')) {
        $errorLines.Add($line)
    }

    # Splitting leaves one empty element where the text ended with a newline,
    # or for no text at all.
    foreach ($lines in $outputLines, $errorLines) {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') {
            $lines.RemoveAt($lines.Count - 1)
        }
    }

    if (-not $SeparateStderr) {
        $outputLines.AddRange($errorLines)
        $errorLines.Clear()
    }

    return @{
        Started     = $true
        ExitCode    = $exitCode
        Output      = $outputLines.ToArray()
        ErrorOutput = $errorLines.ToArray()
        TimedOut    = $timedOut
    }
}
