function Invoke-NativeRead {
    <#
    .SYNOPSIS
        Runs an external command whose failure is survivable,
        and returns whether it worked along with what it said.
    .DESCRIPTION
        For a read whose failure must not end the run, but must not be
        mistaken for an answer either: the exit code is reported rather than
        discarded, and the output is kept whatever it was - some tools write
        their error bodies to stdout, and a caller may need to read them.
        What the command printed comes back exactly as printed: run it
        through Hide-UrlCredential, a line at a time, before showing it.

        Nothing the command does makes this throw. A command that cannot be
        started at all - not found, not executable, or no such working
        directory - reports Started and Ok as false with ExitCode 127, the
        shell's own "command not found", and the reason as its only output,
        with any credential a URL in it carries hidden by Hide-UrlCredential.
        One that times out reports Ok as false, TimedOut as true, and
        ExitCode 124, the code GNU timeout uses, with whatever it had
        printed by then. What still throws is a mistake in the call itself -
        a -WorkingDirectory that is not a folder on disk, an -Environment
        name that cannot be a variable's, one of
        " & | < > ^ % in an argument to a batch file, or a --% argument the
        call operator would drop - and an error raised
        by a PowerShell function or script run as the command, just as
        calling it directly would. Such a throw is a terminating error for
        this call, and under -ErrorAction SilentlyContinue or Ignore it
        still ends the call.

        The command never reads the console: with no -StdIn its input is
        already at its end, so a tool that asks a question reads no answer
        instead of waiting, unseen, for one.

        Output is decoded as UTF-8, and the console's code pages are pinned
        to UTF-8 for the call, so a tool that writes to the console's code
        page writes UTF-8, and one that reads -StdIn through it reads UTF-8.
        A tool that always writes UTF-16 or a legacy code page comes back
        garbled.

        Merged output keeps the order the lines arrived in. With
        -Environment or -TimeoutSeconds the command runs as a process of
        its own, and merged output is then all of stdout followed by all of
        stderr.

        Resets $LASTEXITCODE to 0 before returning, so a tolerated failure
        does not leave a phantom behind for a later, unrelated check to trip
        on.

        With -Verbose, the command line is written to the verbose stream
        before the command runs, with credentials a URL carries and the
        values of -Mask hidden. What goes to -StdIn and the values of
        -Environment are never shown.
        A caller's own -Verbose, or its $VerbosePreference, reaches this
        command even from another module.
    .PARAMETER Command
        The command to run. A PowerShell function or alias of the same name
        runs ahead of an executable, as it would typed at the prompt; with
        -Environment or -TimeoutSeconds only an executable is run. A
        function, cmdlet, or script run as the command gets no pipeline
        input unless -StdIn is given, so it binds as it would called
        directly. A relative path is looked up where the command runs:
        in -WorkingDirectory when one is given.
    .PARAMETER Argument
        One element per argument, as an explicit array; -Arguments is an
        alias. The arguments of a PowerShell function, cmdlet, or script are
        positional: @('-Y', 'why') binds '-Y' as the first positional value,
        not as the parameter -Y. An empty string, an empty array, and $null
        are all allowed. A batch
        file (.cmd or .bat) on Windows is the exception: cmd.exe parses its
        arguments again, so without -Environment or -TimeoutSeconds an empty
        one is dropped, and either way an argument holding any of
        " & | < > ^ % - even a single % - is refused with a throw, because
        there those characters would run commands, redirect, or expand
        variables; the arguments are joined into one command line, so a % in
        one can pair with a % in the next. Call the program's real .exe
        instead, or pass such a value through -StdIn, -Environment, or a
        file. An argument that is exactly --% is refused for a program
        without -Environment or -TimeoutSeconds, because PowerShell drops it
        there even quoted; with either it is passed as it is, and a
        PowerShell command gets it either way.
    .PARAMETER StdIn
        Piped to the command instead of appearing in its arguments, as UTF-8
        with no byte-order mark, ended with one newline. A command that
        exits without reading it is not a failure.
    .PARAMETER WorkingDirectory
        The directory to run in, a folder on disk. A missing one is reported
        as a command that could not start; one on another provider, such as
        HKCU:\Software or Env:\, is refused with a throw naming it. A
        relative one is relative to PowerShell's current location, which is
        also where the command runs when this is left out.
    .PARAMETER Environment
        Variables set for the command alone, over a copy of this process's;
        a $null value removes one. A name that is empty, blank, or contains
        '=' cannot be a variable's and is refused with a throw. The command
        is then run directly, so it must be an executable, not a PowerShell
        function, alias, or script.
    .PARAMETER TimeoutSeconds
        How long the whole call may take before the command is killed, along
        with any process it started that still holds its output open. Like
        -Environment, it runs the command directly.
    .PARAMETER SeparateStderr
        Returns stderr as ErrorOutput instead of merging it into Output.
    .PARAMETER Mask
        Values to hide in the verbose line, as Hide-MaskedValue hides them,
        and in the message of a throw that names the working directory. What
        the command printed, and the reason a command could not be started,
        come back exactly as they are, so pass them through Hide-MaskedValue
        before showing them. A value of fewer than four characters is
        ignored, and so is $null or an empty entry. Plain text only: a
        SecureString is refused, since it would hide just its type name. Give
        a secret by variable: PowerShell's own error view quotes the line of
        the calling script, so a secret written in it is shown there.
    .INPUTS
        None.
    .OUTPUTS
        System.Collections.Hashtable. Ok (bool), Started (bool, false only
        when the command could not be run at all), ExitCode (int), Output
        (string[]), ErrorOutput (string[], empty unless -SeparateStderr), and
        TimedOut (bool). The arrays are never $null.
    .EXAMPLE
        $read = Invoke-NativeRead 'git' @('rev-parse', '--show-toplevel') `
            -SeparateStderr
        if (-not $read.Started) {
            throw 'git is not installed.'
        }

        $root = if ($read.Ok) { $read.Output[0] }

        Reads a value that may legitimately be missing - outside a repository
        git fails, and $root stays empty - while still telling that apart
        from a tool that is not there at all.
    .EXAMPLE
        $read = Invoke-NativeRead 'some-tool' @('check', '--key', $key) `
            -Mask $key

        Hides the key, which the tool takes only as an argument, in the
        verbose line.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ProcessInvocation/README.md
    .LINK
        Invoke-NativeCommand
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Command,

        [Parameter(Position = 1)]
        [Alias('Arguments')]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Argument = @(),

        [string]$StdIn,

        [string]$WorkingDirectory,

        [System.Collections.IDictionary]$Environment,

        [ValidateRange(1, 86400)]
        [int]$TimeoutSeconds,

        [switch]$SeparateStderr,

        [object[]]$Mask
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        $Mask = @(ConvertTo-MaskList -Mask $Mask)
        if ($null -eq $Argument) {
            $Argument = @()
        }

        $capture = @{ SeparateStderr = $SeparateStderr }
        foreach ($name in 'StdIn', 'WorkingDirectory', 'Environment', 'TimeoutSeconds') {
            if ($PSBoundParameters.ContainsKey($name)) {
                $capture[$name] = $PSBoundParameters[$name]
            }
        }

        $result = Invoke-NativeCapture -Command $Command -Arguments $Argument -Mask $Mask @capture
        $global:LASTEXITCODE = 0

        return @{
            Ok          = ($result.Started -and -not $result.TimedOut -and $result.ExitCode -eq 0)
            Started     = $result.Started
            ExitCode    = $result.ExitCode
            Output      = $result.Output
            ErrorOutput = $result.ErrorOutput
            TimedOut    = $result.TimedOut
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
