using namespace System.Diagnostics

function Invoke-TestFileProcess {
    <#
    .SYNOPSIS
        Runs one test file in a fresh pwsh under a coverage wrapper script,
        and returns its result: name, tally, exit code, time, and captured output.
    .DESCRIPTION
        The spawn itself goes through Invoke-NativeRead: a crashing or
        failing test file is an ordinary, survivable result here, not an
        error this function should throw on - exactly the case
        Invoke-NativeRead exists for.
    .PARAMETER File
        The *.Tests.ps1 to run.
    .PARAMETER Name
        The display name to attach to the result.
    .PARAMETER SourceRoot
        Passed straight through to the wrapper.
    .PARAMETER ReportPath
        Passed straight through to the wrapper.
    .PARAMETER ResultPath
        Passed straight through to the wrapper.
    .PARAMETER WrapperPath
        The script to spawn - it decides how the file actually runs under coverage
        (this module makes no assumption about that mechanism).
        It must accept -TestFile, -SourceRoot, -OutputPath, and -ResultPath,
        and exit with the test file's own exit code.
    #>
    param(
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$ReportPath,
        [Parameter(Mandatory)][string]$ResultPath,
        [Parameter(Mandatory)][string]$WrapperPath
    )

    $pwsh = [Process]::GetCurrentProcess().MainModule.FileName
    $arguments = @(
        '-NoProfile', '-NonInteractive', '-File', $WrapperPath
        '-TestFile', $File
        '-SourceRoot', $SourceRoot
        '-OutputPath', $ReportPath
        '-ResultPath', $ResultPath
    )

    $clock = [Stopwatch]::StartNew()
    $read = Invoke-NativeRead -Command $pwsh -Arguments $arguments
    $clock.Stop()

    $tally = Read-TestTally -Output $read.Output -ExitCode $read.ExitCode

    return [pscustomobject]@{
        Name     = $Name
        Passed   = $tally.Passed
        Failed   = $tally.Failed
        Crashed  = $tally.Crashed
        ExitCode = $read.ExitCode
        Seconds  = $clock.Elapsed.TotalSeconds
        Output   = $read.Output
    }
}
