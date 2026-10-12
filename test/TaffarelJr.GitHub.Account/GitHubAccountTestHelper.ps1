using namespace System.IO

# Shared by this module's tests, for what the in-process fake gh of
# GitHubTestHelper.ps1 cannot show: the bytes a native gh reads on standard
# input, and how a function behaves in a session with no host. A test-only
# fixture - nothing here is exported.

$accountModules = 'TaffarelJr.ProcessInvocation', 'TaffarelJr.GitHub.Core', 'TaffarelJr.GitHub.Account'
$accountManifests = foreach ($name in $accountModules) {
    Join-Path $PSScriptRoot '..' '..' 'src' $name "$name.psd1"
}

function Invoke-HostlessScript {
    <#
    .SYNOPSIS
        Runs a script in a new runspace that has no host, and returns what
        it wrote and its debug messages.
    .DESCRIPTION
        Not exported - a test-only fixture. With no host to ask, a missing
        mandatory parameter throws instead of prompting, and Set-PSDebug's
        trace arrives as debug messages instead of on the console, so a test
        can check both. The runspace imports this module and the modules it
        needs by path; the first error the script reports, terminating or
        not, is thrown here.
        It shares this process's environment, so a fake gh put on PATH
        answers in it too.
    .PARAMETER Script
        The code to run.
    .OUTPUTS
        An object - Output (what the script wrote) and Debug (the text of
        each debug message, the trace included).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Script
    )

    $shell = [powershell]::Create()
    try {
        foreach ($manifest in $accountManifests) {
            $import = $shell.AddCommand('Import-Module').AddParameter('Name', $manifest)
            $null = $import.AddParameter('Force').AddStatement()
        }

        $null = $shell.AddScript("`$ErrorActionPreference = 'Stop'`n$Script")
        $output = $shell.Invoke()
        if ($shell.Streams.Error.Count -gt 0) {
            throw $shell.Streams.Error[0]
        }

        $debug = @($shell.Streams.Debug | ForEach-Object Message)
        return [PSCustomObject]@{
            Output = @($output)
            Debug  = $debug
        }
    }
    finally {
        $shell.Dispose()
    }
}

function New-NativeStdInRecorder {
    <#
    .SYNOPSIS
        Puts a native gh first on PATH that saves every byte it reads on
        standard input.
    .DESCRIPTION
        Not exported - a test-only fixture. The fake gh of
        GitHubTestHelper.ps1 runs in-process and sees -StdIn as a .NET
        string; this one is a process of its own - gh.cmd on Windows, a gh
        shell script elsewhere, each starting PowerShell on a recording
        script - so it reads the bytes a real gh would: the encoding, any
        byte-order mark, the line ending. It prints nothing and exits 0.
        Always remove it in a finally block.

        In case the shim is ever passed over, the real gh would still find
        nothing of this machine: GH_CONFIG_DIR is the recorder's own
        folder, GH_HOST is github.localhost, and the token variables are
        cleared. GH_TELEMETRY=false and DO_NOT_TRACK=1 keep gh from sending
        telemetry. Remove-NativeStdInRecorder puts each one back.
    .OUTPUTS
        A fixture object (Path, OriginalPath, OriginalEnvironment) for
        Get-NativeStdInHex and Remove-NativeStdInRecorder.
    #>
    [CmdletBinding()]
    param()

    $path = Join-Path ([Path]::GetTempPath()) "gh-stdin-$([Guid]::NewGuid())"
    New-Item -ItemType Directory -Path $path | Out-Null

    $record = @(
        '$stdin = [Console]::OpenStandardInput()'
        '$bytes = [System.IO.MemoryStream]::new()'
        '$stdin.CopyTo($bytes)'
        '[System.IO.File]::WriteAllBytes((Join-Path $PSScriptRoot ''stdin.bin''), $bytes.ToArray())'
    )
    $script = Join-Path $path 'record.ps1'
    [File]::WriteAllLines($script, [string[]]$record)

    $pwsh = (Get-Process -Id $PID).Path
    if ($IsWindows) {
        $shim = @(
            "@`"$pwsh`" -NoProfile -NonInteractive -File `"$script`" %*"
            '@exit /b %ERRORLEVEL%'
        )
        [File]::WriteAllLines((Join-Path $path 'gh.cmd'), [string[]]$shim)
    }
    else {
        $quote = { param($Text) "'" + $Text.Replace("'", "'\''") + "'" }
        $shimPath = Join-Path $path 'gh'
        $exec = "exec $(& $quote $pwsh) -NoProfile -NonInteractive -File $(& $quote $script) `"`$@`""
        [File]::WriteAllText($shimPath, "#!/bin/sh`n$exec`n")
        & chmod '+x' $shimPath
    }

    $environment = [ordered]@{
        GH_CONFIG_DIR           = $path
        GH_HOST                 = 'github.localhost'
        GH_TOKEN                = $null
        GH_ENTERPRISE_TOKEN     = $null
        GITHUB_TOKEN            = $null
        GITHUB_ENTERPRISE_TOKEN = $null
        GH_TELEMETRY            = 'false'
        DO_NOT_TRACK            = '1'
    }
    $saved = [ordered]@{}
    foreach ($name in $environment.PSBase.Keys) {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name)
    }

    $fixture = [PSCustomObject]@{
        Path                = $path
        OriginalPath        = $env:PATH
        OriginalEnvironment = $saved
    }
    foreach ($name in $environment.PSBase.Keys) {
        [Environment]::SetEnvironmentVariable($name, $environment[$name])
    }

    $env:PATH = "$path$([Path]::PathSeparator)$env:PATH"

    return $fixture
}

function Get-NativeStdInHex {
    <#
    .SYNOPSIS
        Returns the bytes the native recorder read on standard input, as
        hexadecimal text.
    .DESCRIPTION
        Not exported - a test-only fixture. Throws when the recorder was
        never run, so a call that did not reach it cannot pass as one that
        sent nothing.
    .PARAMETER Fixture
        The object New-NativeStdInRecorder returned.
    .OUTPUTS
        The bytes as upper-case hexadecimal text, two digits each.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture
    )

    $file = Join-Path $Fixture.Path 'stdin.bin'
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "The native gh recorder in '$($Fixture.Path)' was never run."
    }

    return [Convert]::ToHexString([File]::ReadAllBytes($file))
}

function Remove-NativeStdInRecorder {
    <#
    .SYNOPSIS
        Takes the native recorder back off PATH and deletes it.
    .DESCRIPTION
        Not exported - a test-only fixture.
    .PARAMETER Fixture
        The object New-NativeStdInRecorder returned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Fixture
    )

    $env:PATH = $Fixture.OriginalPath
    foreach ($name in $Fixture.OriginalEnvironment.PSBase.Keys) {
        [Environment]::SetEnvironmentVariable($name, $Fixture.OriginalEnvironment[$name])
    }

    Remove-Item -LiteralPath $Fixture.Path -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-CallerScript {
    <#
    .SYNOPSIS
        Runs a script as an ordinary caller's script runs, in a new runspace,
        and returns what it wrote and the errors it reported.
    .DESCRIPTION
        Not exported - a test-only fixture. A statement that fails with a
        terminating error ends there, the error is reported, and the script
        carries on at its next line. Inside a test's own try block the same
        failure would be thrown to that block instead, so a test of what a
        caller sees under -ErrorAction SilentlyContinue or Ignore runs the
        call here, with no try around it.

        The runspace imports this module and the modules it needs by path,
        and shares this process's environment, so a fake gh put on PATH
        answers in it too.
    .PARAMETER Script
        The code to run.
    .OUTPUTS
        An object - Output (what the script wrote) and Error (the error
        records it reported, as the runspace's error stream holds them).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Script
    )

    $shell = [powershell]::Create()
    try {
        foreach ($manifest in $accountManifests) {
            $import = $shell.AddCommand('Import-Module').AddParameter('Name', $manifest)
            $null = $import.AddParameter('Force').AddStatement()
        }

        $null = $shell.AddScript($Script)
        $output = $shell.Invoke()
        return [PSCustomObject]@{
            Output = @($output)
            Error  = @($shell.Streams.Error)
        }
    }
    finally {
        $shell.Dispose()
    }
}

function Get-GitHubCallOutcome {
    <#
    .SYNOPSIS
        Runs a script block and reports everything a secret could leak
        through: what it said, and how it failed.
    .DESCRIPTION
        Not exported - a test-only fixture. Collects the verbose lines as
        they are written, so those written before a failure are kept, and
        clears $Error first so $Error[0] is this call's own failure.
    .PARAMETER ScriptBlock
        The call to make.
    .OUTPUTS
        An object - Message, Target and the text PowerShell renders for the
        error (Rendered), what Get-Error shows for the error it was thrown as
        (Detail) and for $Error[0] (Last); all empty when nothing failed. Also
        Verbose, each verbose line, and Output, what was written to the
        pipeline.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $raised = $null
    $seen = [System.Collections.Generic.List[object]]::new()
    $global:Error.Clear()
    try {
        & $ScriptBlock 4>&1 | ForEach-Object { $seen.Add($_) }
    }
    catch {
        $raised = $_
    }

    $record = [System.Management.Automation.VerboseRecord]
    $verbose = @($seen | Where-Object { $_ -is $record } | ForEach-Object { $_.Message })
    $output = @($seen | Where-Object { $_ -isnot $record })
    return [PSCustomObject]@{
        Message  = if ($raised) { $raised.Exception.Message } else { '' }
        Target   = if ($raised) { $raised.TargetObject } else { $null }
        Rendered = if ($raised) { ($raised | Out-String) } else { '' }
        Detail   = if ($raised) { ($raised | Get-Error | Out-String) } else { '' }
        Last     = if ($raised) { (Get-Error | Out-String) } else { '' }
        Verbose  = $verbose
        Output   = $output
    }
}

function Get-LeakingSurface {
    <#
    .SYNOPSIS
        Names each place a text shows up in what Get-GitHubCallOutcome
        reported.
    .DESCRIPTION
        Not exported - a test-only fixture. An empty answer means the text
        is in none of the message, the error's target, the way PowerShell
        renders the error, what Get-Error shows, and the verbose lines.
    .PARAMETER Outcome
        What Get-GitHubCallOutcome returned.
    .PARAMETER Text
        The text that must appear nowhere.
    .OUTPUTS
        The name of each surface that holds the text, one at a time.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Outcome,

        [Parameter(Mandatory)]
        [string]$Text
    )

    $surfaces = [ordered]@{
        Message  = $Outcome.Message
        Target   = "$($Outcome.Target)"
        Rendered = $Outcome.Rendered
        Detail   = $Outcome.Detail
        Last     = $Outcome.Last
        Verbose  = $Outcome.Verbose -join "`n"
    }

    foreach ($name in $surfaces.Keys) {
        if ($surfaces[$name].Contains($Text)) {
            $name
        }
    }
}
