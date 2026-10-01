using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Text

function Invoke-NativeCapture {
    <#
    .SYNOPSIS
        Runs an external command and returns its exit code and output.
    .DESCRIPTION
        Not exported - the one place output is captured and decoded, so
        Invoke-NativeCommand and Invoke-NativeRead cannot disagree about
        either.

        By default stderr is merged into the output, in the order it
        arrived: many tools write ordinary progress there even on success,
        and some write their error bodies to stdout, so a caller needs both
        whichever a tool favors. -SeparateStderr keeps it apart instead, for
        a caller that parses stdout and cannot have a warning in it. A blank
        line on stderr stays a blank line.

        Output is decoded as UTF-8, which many tools emit regardless of the
        console's code page, and the console is pinned to UTF-8 for the
        call, so a child that encodes to the console's code page writes
        UTF-8 too.

        The command never reads the console: with no -StdIn its input is
        already at its end, so a tool that asks a question reads no answer
        instead of waiting, unseen, for one.

        The caller's own state must not reach the command, so four things
        are pinned for the call: $LASTEXITCODE, which a command that is a
        function or alias never sets, so a stale value would be read as its
        result; $PSNativeCommandUseErrorActionPreference, which would turn a
        reported failure into a throw; $PSNativeCommandArgumentPassing,
        which would drop empty arguments and strip quotes; and
        $OutputEncoding, which would encode -StdIn as the caller's profile
        chose, a byte-order mark included. $LASTEXITCODE is left holding
        the command's exit code, whichever route ran it.

        -Environment and -TimeoutSeconds are what PowerShell's call operator
        cannot do, so a call using either goes to Invoke-NativeProcess, which
        runs the program directly: it must be an executable, not a
        PowerShell function, alias, or script.

        A command that cannot be started at all - not found, not executable,
        or no such working directory - is reported rather than thrown, so
        each caller decides what that means: Started is $false, ExitCode is
        127 (the shell's own "command not found"), and Output is the reason,
        with any credential a URL in it carries hidden.

        The one place every call passes through, so it is where the command
        line is written to the verbose stream, before anything runs. It
        reads $VerbosePreference as its caller left it. Credentials a URL
        carries and the values of -Mask are hidden; what goes to -StdIn and
        the values of -Environment are never shown. What it returns is not
        masked: each caller decides what to show.
    .PARAMETER Command
        The command to run. Through the call operator a PowerShell function
        or alias of the same name runs ahead of an executable, as it would
        typed at the prompt; with -Environment or -TimeoutSeconds only an
        executable is run. A function, cmdlet, or script run as the command
        gets no pipeline input unless -StdIn is given, so it binds as it
        would called directly. A relative path is looked up where the
        command runs: in -WorkingDirectory when one is given. A wildcard
        character in it is part of the name: only a command of exactly that
        name, or a file at exactly that path, is run.
    .PARAMETER Arguments
        One element per argument, as an explicit array: a loose token like
        '-C' would otherwise bind as a PowerShell parameter instead of an
        argument to the command, without any error. Those of a PowerShell
        command are positional: @('-Y', 'why') binds '-Y' as the first
        positional value, not as the parameter -Y. An empty string is a
        real, empty argument; an empty array runs the command bare. A batch
        file (.cmd or .bat) on Windows is the exception: cmd.exe parses its
        arguments again, so through the call operator an empty one is
        dropped, and an argument holding any of " & | < > ^ % - even a
        single % - is refused with a throw on either route, because there
        those characters would run commands, redirect, or expand variables.
        An argument that is exactly --% is refused for a program through the
        call operator, which drops it even quoted; with -Environment or
        -TimeoutSeconds it is passed as it is, and a PowerShell command gets
        it either way.
    .PARAMETER StdIn
        Piped to the command instead of appearing in its arguments, as UTF-8
        with no byte-order mark. It is ended with one newline, the
        platform's own, and an empty string sends just that newline -
        PowerShell offers no way to send it bare.
    .PARAMETER WorkingDirectory
        The directory to run in, a folder on disk. A missing one is reported
        as a command that could not start; one on another provider, such as
        HKCU:\Software or Env:\, is refused with a throw naming it. A
        relative one is relative to PowerShell's current location, which is
        also where the command runs when this is left out.
    .PARAMETER Environment
        Variables set for the command alone, over a copy of this process's.
        A $null value removes one. A name that is empty, blank, or contains
        '=' cannot be a variable's and is refused with a throw.
    .PARAMETER TimeoutSeconds
        How long the whole call may take before the command is killed. Omit
        it to wait for ever.
    .PARAMETER SeparateStderr
        Returns stderr as ErrorOutput instead of merging it into Output.
    .PARAMETER Mask
        Values to hide, as Hide-MaskedValue hides them, in the verbose line and
        in a message that names the working directory.
    .OUTPUTS
        A hashtable: Started (bool), ExitCode (int), Output (string[]),
        ErrorOutput (string[], empty unless -SeparateStderr), and TimedOut
        (bool, with ExitCode 124 when it is). The arrays are never $null.
    #>
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

        [string[]]$Mask
    )

    if ($VerbosePreference -ne 'SilentlyContinue') {
        $line = Format-NativeCommandLine -Command $Command -Arguments $Arguments -Mask $Mask
        if ($WorkingDirectory) {
            $maskedDirectory = Hide-MaskedValue -Text $WorkingDirectory -Mask $Mask
            $line += " (in $(Hide-UrlCredential -Text $maskedDirectory))"
        }

        Write-Verbose "Running: $line"
    }

    if ($WorkingDirectory -and -not (Test-Path -LiteralPath $WorkingDirectory -PathType Container)) {
        return @{
            Started     = $false
            ExitCode    = 127
            Output      = [string[]]@("Working directory not found: $(Hide-UrlCredential -Text $WorkingDirectory)")
            ErrorOutput = [string[]]@()
            TimedOut    = $false
        }
    }

    # A program can only start in a folder on disk; elsewhere it would quietly
    # start in the last file-system folder PowerShell was in.
    if ($WorkingDirectory) {
        $provider = (Resolve-Path -LiteralPath $WorkingDirectory | Select-Object -First 1).Provider
        if ($provider.Name -ne 'FileSystem') {
            $maskedDirectory = Hide-MaskedValue -Text $WorkingDirectory -Mask $Mask
            $shown = Hide-UrlCredential -Text $maskedDirectory
            throw "-WorkingDirectory '$shown' is on the $($provider.Name) provider: give a folder on disk."
        }
    }

    # Everything from the lookup to the call happens in the directory the
    # command runs in, so a relative command is found where it will run and
    # the batch-file guard checks the file that runs.
    if ($WorkingDirectory) {
        Push-Location -LiteralPath $WorkingDirectory
    }

    try {
        # Resolved once, as the route will run it, and the call operator runs
        # exactly what was resolved, so the guards and the call cannot disagree:
        # the process route runs only an executable, the call operator follows
        # an alias to its target.
        $isDirect = $Environment -or $TimeoutSeconds -gt 0
        $resolved = Find-NativeCommand -Command $Command -ApplicationOnly:$isDirect
        if ($resolved -is [AliasInfo]) {
            $resolved = $resolved.ResolvedCommand
        }

        Assert-BatchFileArgument -Command $resolved -Arguments $Arguments

        $stopParsing = [Array]::IndexOf($Arguments, '--%')
        if (-not $isDirect -and $resolved -is [ApplicationInfo] -and $stopParsing -ge 0) {
            throw "Argument $($stopParsing + 1) is '--%', which PowerShell drops from a program's arguments" +
            ' through the call operator, even quoted.' +
            ' Give -TimeoutSeconds or -Environment, which run the program directly and pass it as it is.'
        }

        $global:LASTEXITCODE = 0
        if ($isDirect) {
            # No -WorkingDirectory: the process starts where PowerShell now is,
            # which is already that directory.
            $direct = @{
                Command        = $Command
                Arguments      = $Arguments
                SeparateStderr = $SeparateStderr
            }

            if ($null -ne $resolved) {
                $direct.Program = $resolved.Source
            }

            foreach ($name in 'StdIn', 'Environment', 'TimeoutSeconds') {
                if ($PSBoundParameters.ContainsKey($name)) {
                    $direct[$name] = $PSBoundParameters[$name]
                }
            }

            Enter-Utf8Console
            try {
                $result = Invoke-NativeProcess @direct
            }
            finally {
                Exit-Utf8Console
            }

            if ($result.Started) {
                $global:LASTEXITCODE = $result.ExitCode
            }

            return $result
        }

        $PSNativeCommandUseErrorActionPreference = $false
        $PSNativeCommandArgumentPassing = if ($IsWindows) { 'Windows' } else { 'Standard' }
        $OutputEncoding = [UTF8Encoding]::new($false)

        # An empty pipeline gives an executable an input already at its end,
        # where no pipeline would hand it the console. A PowerShell command gets
        # no pipeline at all, so it binds exactly as it would called directly.
        $isPowerShellCommand = $resolved -is [FunctionInfo] -or
        $resolved -is [CmdletInfo] -or
        $resolved -is [ExternalScriptInfo]
        $isPiped = $PSBoundParameters.ContainsKey('StdIn') -or -not $isPowerShellCommand
        $piped = @()
        if ($PSBoundParameters.ContainsKey('StdIn')) {
            $piped = @($StdIn)
        }

        # Nothing resolved: the name itself, so the call operator reports it.
        $target = $Command
        if ($null -ne $resolved) {
            $target = $resolved
        }

        Enter-Utf8Console
        try {
            if ($isPiped) {
                $out = $piped | & $target @Arguments 2>&1
            }
            else {
                $out = & $target @Arguments 2>&1
            }

            $exitCode = $LASTEXITCODE
        }
        catch [CommandNotFoundException], [ApplicationFailedException] {
            $reason = @($_.Exception.Message -split '\r?\n' | Hide-UrlCredential)
            return @{
                Started     = $false
                ExitCode    = 127
                Output      = [string[]]$reason
                ErrorOutput = [string[]]@()
                TimedOut    = $false
            }
        }
        finally {
            Exit-Utf8Console
        }
    }
    finally {
        if ($WorkingDirectory) {
            Pop-Location
        }
    }

    # Lines, never a bare string or $null: one line must stay an array, and a
    # command that printed nothing must still give an empty one. Anything on
    # the error stream was written to stderr, and an ErrorRecord for a blank
    # line would otherwise read as its exception's type name.
    $stdout = [List[string]]::new()
    $stderr = [List[string]]::new()
    foreach ($item in $out) {
        $text = if ($item -is [ErrorRecord]) { $item.Exception.Message } else { "$item" }
        if ($SeparateStderr -and $item -is [ErrorRecord]) {
            $stderr.Add($text)
        }
        else {
            $stdout.Add($text)
        }
    }

    return @{
        Started     = $true
        ExitCode    = $exitCode
        Output      = $stdout.ToArray()
        ErrorOutput = $stderr.ToArray()
        TimedOut    = $false
    }
}
