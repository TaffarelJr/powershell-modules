using namespace System.Diagnostics
using namespace System.IO

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
        One or more folders, joined with the platform path separator
        before being passed to the wrapper - a child process started from
        an argument array only ever binds the first bare value following a
        flag to a [string[]] parameter, silently dropping the rest, so the
        list has to cross that boundary as one delimited string instead.
    .PARAMETER ReportPath
        Passed straight through to the wrapper.
    .PARAMETER ResultPath
        Passed straight through to the wrapper.
    .PARAMETER WrapperPath
        The script to spawn - it decides how the file actually runs under coverage
        (this module makes no assumption about that mechanism).
        It must accept -TestFile, -SourceRoot, -OutputPath, and -ResultPath,
        and exit with the test file's own exit code.
        Defaults to this module's own Scripts/Invoke-TestFile.ps1 -
        override it only for a different Pester configuration.
    #>
    param(
        [Parameter(Mandatory)][string]$File,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string[]]$SourceRoot,
        [Parameter(Mandatory)][string]$ReportPath,
        [Parameter(Mandatory)][string]$ResultPath,
        [string]$WrapperPath = (Join-Path $PSScriptRoot '..' 'Scripts' 'Invoke-TestFile.ps1')
    )

    $pwsh = [Process]::GetCurrentProcess().MainModule.FileName
    $arguments = @(
        '-NoProfile', '-NonInteractive', '-File', $WrapperPath
        '-TestFile', $File
        '-SourceRoot', ($SourceRoot -join [Path]::PathSeparator)
        '-OutputPath', $ReportPath
        '-ResultPath', $ResultPath
    )

    $clock = [Stopwatch]::StartNew()
    $read = Invoke-NativeRead -Command $pwsh -Arguments $arguments
    $clock.Stop()

    $tally = Read-TestTally -Output $read.Output -ExitCode $read.ExitCode

    return [PSCustomObject]@{
        Name     = $Name
        Passed   = $tally.Passed
        Failed   = $tally.Failed
        Crashed  = $tally.Crashed
        ExitCode = $read.ExitCode
        Seconds  = $clock.Elapsed.TotalSeconds
        Output   = $read.Output
    }
}
