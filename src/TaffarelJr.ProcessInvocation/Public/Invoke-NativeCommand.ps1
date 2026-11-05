function Invoke-NativeCommand {
    <#
    .SYNOPSIS
        Runs an external command with its output captured,
        and throws if it fails.
    .DESCRIPTION
        Only for calls where a non-zero exit is genuinely an error.
        A call whose failure is itself a meaningful answer
        rather than an error should use Invoke-NativeRead instead.

        Every failure throws a message saying what was being attempted and
        why it failed: the command line, quoted so it can be pasted back
        into PowerShell (except a --% argument, which no pasted line can
        pass), with the exit code and the command's own output,
        or - for a command that could not be started at all, or that timed
        out - the reason. Any credential a URL carries is hidden there, as
        Hide-UrlCredential hides it: in the activity, in each word of the
        command line, and in each line the command printed, each on its
        own, so an @ in one cannot hide another. A secret that is not part
        of a URL, and has to travel as an argument, is named in -Mask and
        hidden the same way, as Hide-MaskedValue hides it. A tool that may
        echo a configuration or a credential it was not given is run with
        -HideOutput, which leaves what it printed out of the message.

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

        $LASTEXITCODE is left holding the command's exit code, so a later
        Assert-ExitCode sees this call's result rather than an older one.

        With -Verbose, the command line is written to the verbose stream
        before the command runs, with credentials and -Mask values hidden as
        in a failure message. What goes to -StdIn and the values of
        -Environment are never shown. A caller's own -Verbose, or its
        $VerbosePreference, reaches this command even from another module.

        A failure is a terminating error for this call. Under
        -ErrorAction SilentlyContinue or Ignore it still ends the call, so
        no output is returned for a command that failed.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
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
        with no byte-order mark, ended with one newline. Use this for a value
        that must not reach the console: the failure message renders the
        whole argument vector, so a secret passed as an argument, other than
        a URL's credential, would be printed by it unless -Mask names it. A
        command that exits without reading it is not a failure.
    .PARAMETER WorkingDirectory
        The directory to run in, a folder on disk. A missing one throws as a
        command that could not start; one on another provider, such as
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
        with any process it started that still holds its output open, and
        the call throws. Like -Environment, it runs the command directly.
    .PARAMETER SeparateStderr
        Returns only stdout, so a warning on stderr cannot end up in what the
        caller parses. Stderr still appears in a failure message.
    .PARAMETER Mask
        Values to hide wherever this command shows them: in the failure
        message - the activity, each word of the command line, the reason,
        and each line the command printed - and in the verbose line. Each
        is replaced by *** as Hide-MaskedValue does, so a value of fewer
        than four characters is ignored, and $null or an empty entry is
        too. What the command returns on success is not changed, and neither
        is an error a PowerShell function run as the command raises itself.
        Plain text only: a SecureString is refused, since it would hide just
        its type name. Give a secret by variable: PowerShell's own error view
        quotes the line of the calling script, so a secret written in it is
        shown there.
    .PARAMETER HideOutput
        Leaves what the command printed, on stdout and stderr, out of the
        failure message, for a tool that may echo a configuration or a
        credential; the message keeps the activity, the command line, and the
        exit code or the timeout. What the command returns on success is not
        changed, and a command that could not be run still gives its reason.
    .INPUTS
        None.
    .OUTPUTS
        System.String. The command's output, one line at a time, as a native
        command's would be. Wrap the call in @() to collect it as an array -
        one line, or none, would otherwise come back as a string or $null.
    .EXAMPLE
        $files = @(Invoke-NativeCommand -Activity 'Listing tracked files' `
                -Command 'git' -Argument @('ls-files'))

        Collects a command's output as an array, and throws
        "Listing tracked files failed: git ls-files (exit 128)" followed by
        git's own message when the folder is not a repository.
    .EXAMPLE
        Invoke-NativeCommand 'gh' @('auth', 'login', '--with-token') `
            -StdIn $token -Activity 'Saving the token'

        Hands a secret over on standard input, where a failure message
        never shows it.
    .EXAMPLE
        Invoke-NativeCommand 'some-tool' @('login', '--password', $password) `
            -Activity 'Signing in' -Mask $password

        Hides the password, which the tool takes only as an argument, in the
        failure message and in the verbose line.
    .EXAMPLE
        Invoke-NativeCommand -Activity 'Reading the settings' -Command 'git' `
            -Argument @('config', '--list') -HideOutput

        Throws when git fails, naming the activity, the command line, and the
        exit code, but not the lines git printed.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ProcessInvocation/README.md
    .LINK
        Invoke-NativeRead
    .LINK
        Assert-ExitCode
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,

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

        [object[]]$Mask,

        [switch]$HideOutput
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
        $maskedActivity = Hide-MaskedValue -Text $Activity -Mask $Mask
        $shownActivity = Hide-UrlCredential -Text $maskedActivity
        if (-not $result.Started) {
            $maskedCommand = Hide-MaskedValue -Text $Command -Mask $Mask
            $shownCommand = Hide-UrlCredential -Text $maskedCommand
            $shownWhy = Hide-MaskedValue -Text $result.Output[0] -Mask $Mask
            throw "$shownActivity failed: could not run $shownCommand ($shownWhy)"
        }

        if ($result.TimedOut -or $result.ExitCode -ne 0) {
            $call = Format-NativeCommandLine -Command $Command -Arguments $Argument -Mask $Mask
            $reason = "exit $($result.ExitCode)"
            if ($result.TimedOut) {
                $reason = "timed out after $TimeoutSeconds seconds"
            }

            $message = "$shownActivity failed: $call ($reason)"
            if (-not $HideOutput) {
                $lines = @(@($result.Output) + @($result.ErrorOutput))
                $printed = @($lines | Hide-MaskedValue -Mask $Mask | Hide-UrlCredential)
                $detail = ($printed -join "`n").Trim()
                if ($detail) {
                    $message += "`n$detail"
                }
            }

            throw $message
        }

        return $result.Output
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
