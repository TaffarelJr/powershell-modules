using namespace System.Diagnostics
using namespace System.IO

# Shared by this module's tests: the running PowerShell to use as a child,
# child commands that report exactly what they were given, and ways to watch
# a child that must never outlive its test. A test-only fixture - nothing
# here is exported.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments',
    '',
    Justification = 'Read by the script block or child process the test hands it to, by scope.')]
param()

$pwsh = (Get-Process -Id $PID).Path
$moduleManifest = Join-Path $PSScriptRoot '..' '..' 'src' 'TaffarelJr.ProcessInvocation' 'TaffarelJr.ProcessInvocation.psd1'

# Prints, as hex, every byte that arrived on standard input.
$dumpStdIn = 'using namespace System.IO; $in = [Console]::OpenStandardInput(); $ms = [MemoryStream]::new(); ' +
'$in.CopyTo($ms); ($ms.ToArray() | ForEach-Object { $_.ToString("x2") }) -join " "'

# Writes UTF-8 bytes straight to stdout, past the child's own encoder.
$emitUtf8 = '$b = [Text.UTF8Encoding]::new($false).GetBytes("cafe-$([char]0xE9)`n"); ' +
'$o = [Console]::OpenStandardOutput(); $o.Write($b, 0, $b.Length); $o.Flush()'

function New-EchoArgsScript {
    <#
    .SYNOPSIS
        Writes a script that prints each argument it gets in brackets, one per
        line, and returns its path.
    .PARAMETER Folder
        Where to write it.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Folder
    )

    $path = Join-Path $Folder 'echo-args.ps1'
    [File]::WriteAllText($path, '$args | ForEach-Object { "[$_]" }')
    return $path
}

function Wait-ProcessIdFile {
    <#
    .SYNOPSIS
        Waits for a child to write its process id to a file, and returns it.
    .DESCRIPTION
        A child that is going to be stopped or killed cannot report its id on
        stdout, which is only read once it ends. Throws rather than wait for
        ever when no id arrives.
    .PARAMETER Path
        The file the child writes its id to.
    .PARAMETER TimeoutSeconds
        How long to wait.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [int]$TimeoutSeconds = 60
    )

    $clock = [Stopwatch]::StartNew()
    while ($clock.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        $text = Get-Content -LiteralPath $Path -Raw -ErrorAction Ignore
        if ($text -match '^\s*(\d+)\s*$') {
            return [int]$Matches[1]
        }

        Start-Sleep -Milliseconds 100
    }

    throw "No process id was written to $Path within $TimeoutSeconds seconds."
}

function Test-ProcessRunning {
    <#
    .SYNOPSIS
        Says whether a process is still running, after giving one that is
        being killed a few seconds to finish dying.
    .PARAMETER Id
        The process id.
    #>
    param(
        [Parameter(Mandatory)]
        [int]$Id
    )

    Wait-Process -Id $Id -Timeout 10 -ErrorAction Ignore
    return $null -ne (Get-Process -Id $Id -ErrorAction Ignore)
}

function Invoke-HiddenConsoleScript {
    <#
    .SYNOPSIS
        Runs a script in a new PowerShell that has a real console of its own,
        hidden, with this module loaded, and returns what the script returned.
    .DESCRIPTION
        For what only a real console shows: a child that inherits it reads the
        keyboard, not a pipe. Its standard streams are that console, so the
        script's result comes back through a file. A run still going at the
        timeout is killed with everything it started, and nothing it started
        is left running either way.
    .PARAMETER Script
        What to run, after the module is imported. What it returns is written
        out one line per item.
    .PARAMETER TimeoutSeconds
        How long to wait.
    .OUTPUTS
        A PSCustomObject with Finished (whether it ended by itself in time)
        and Output (the lines it returned).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Script,

        [int]$TimeoutSeconds = 90
    )

    $folder = Join-Path ([Path]::GetTempPath()) ([Guid]::NewGuid())
    New-Item -ItemType Directory -Path $folder | Out-Null
    $scriptFile = Join-Path $folder 'child.ps1'
    $resultFile = Join-Path $folder 'result.txt'
    $body = "Import-Module '$moduleManifest'`n`$result = & { $Script }`n" +
    "[IO.File]::WriteAllLines('$resultFile', [string[]]@(`$result))`n"
    [File]::WriteAllText($scriptFile, $body)
    $arguments = @('-NoProfile', '-NonInteractive', '-File', "`"$scriptFile`"")
    $process = Start-Process -FilePath $pwsh -ArgumentList $arguments -WindowStyle Hidden -PassThru
    try {
        $finished = $process.WaitForExit($TimeoutSeconds * 1000)
        $output = if (Test-Path -LiteralPath $resultFile) { [File]::ReadAllLines($resultFile) } else { @() }
        return [PSCustomObject]@{
            Finished = $finished
            Output   = [string[]]$output
        }
    }
    finally {
        if (-not $process.HasExited) {
            $process.Kill($true)
        }

        $process.Dispose()
        Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
