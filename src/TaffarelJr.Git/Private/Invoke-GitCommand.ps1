function Invoke-GitCommand {
    <#
    .SYNOPSIS
        Runs git with its output captured - the only function in this
        module that calls TaffarelJr.ProcessInvocation.
    .DESCRIPTION
        By default, throws on a non-zero exit, like Invoke-NativeCommand.
        -Tolerant switches to Invoke-NativeRead's shape instead: a result
        object rather than a throw, for a call whose failure (or empty
        output) is a meaningful answer rather than an error.

        No git command this module runs waits on a person. GIT_EDITOR is set
        to a command that does nothing, so a merge, commit, or rebase that would
        open an editor completes with whatever message git pre-filled; it is
        the one setting that outranks core.editor and every other way a user
        can name an editor. GIT_TERMINAL_PROMPT is set to 0 and GIT_ASKPASS
        to empty, so a command that needs a credential fails saying so
        instead of asking on the console or starting an askpass program
        (an empty GIT_ASKPASS also wins over core.askPass and SSH_ASKPASS).
        GCM_INTERACTIVE is set to never, so Git Credential Manager answers
        from what it has stored and never opens a sign-in window. A
        credential helper still runs and can supply a stored credential.

        With -RepoPath, the variables that select a repository or change its
        view of history - GIT_DIR, GIT_INDEX_FILE, GIT_SHALLOW_FILE,
        GIT_NAMESPACE and the others Get-GitRepositoryVariable lists - are
        removed for the call, since git would otherwise use them ahead of the
        repository -RepoPath names; a git hook sets several of them.
        Configuration passed through the environment, such as
        GIT_CONFIG_COUNT with GIT_CONFIG_KEY_0 and GIT_CONFIG_VALUE_0, is
        kept; GIT_CONFIG, which only points git config at another file, is
        removed with the others.
        -NoRepository removes them too, for a command such as a clone whose
        target is never the repository they name. Otherwise they are left
        alone, and git uses them as it would for any command run there.

        Every call is given -c core.longpaths=true, so git for Windows reads
        a path longer than 260 characters instead of skipping it with a
        warning; git elsewhere ignores the setting.

        Output is stdout alone: a warning on stderr cannot end up in what a
        caller parses. Stderr still appears in a failure message. Any
        credential a URL carries is hidden in a failure message and in a
        -Tolerant result's Message, as Hide-UrlCredential hides it, and each
        -Mask value is hidden there as Hide-MaskedValue hides it: in the
        activity, in each word of the command line, and in each line git
        printed.

        The command line about to run is written to the verbose stream, with
        the credentials and -Mask values hidden the same way, whenever the
        public function that ran it is verbose: it follows that function's
        -Verbose, or the session's $VerbosePreference. It is never more than
        the arguments: no environment, no output.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
        Used in a failure message; with -Tolerant only when git itself
        cannot be found.
    .PARAMETER Arguments
        Passed as an explicit array - a loose token like '-C' would
        otherwise bind as a PowerShell parameter instead of a git argument.
        An empty-string element is allowed - PowerShell's own binder
        rejects one on a bare [string[]] parameter otherwise, even
        though the array itself is never null or empty.
    .PARAMETER RepoPath
        The repo to run in, passed ahead of -Arguments (after the -c above)
        as git's own -C so no directory is ever changed. A relative path or
        a PowerShell drive is resolved against PowerShell's current location
        first. Omit it to run against the current working directory.
    .PARAMETER NoRepository
        Removes the variables that name a repository for the call, as
        -RepoPath does, without naming a repo to run in.
    .PARAMETER Tolerant
        Returns a result object instead of throwing. For a call that uses a
        non-zero exit, or empty output, as its answer rather than as a
        failure. Throws only when git itself cannot be found.
    .PARAMETER Mask
        Values to hide wherever the call shows them, for a call whose
        arguments hold a value its caller supplied and that may be a secret,
        such as a config value: in the verbose line, in a failure message
        with its target, and in a -Tolerant result's Message. A -Tolerant
        result's Output and ErrorOutput stay exactly as git printed them.
        A value of fewer than four characters is ignored.
    .OUTPUTS
        Without -Tolerant: the command's output, one line at a time. Wrap
        the call in @() to collect it as an array.
        With -Tolerant: a hashtable - Ok, Started, ExitCode, TimedOut,
        Output and ErrorOutput (each a string[]), and Message, stdout and
        stderr together as one string, for an error to quote, with each
        line's credentials hidden.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Arguments,

        [string]$RepoPath,

        [switch]$NoRepository,

        [switch]$Tolerant,

        [string[]]$Mask
    )

    if (-not $PSBoundParameters.ContainsKey('Verbose')) {
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
    }

    $environment = @{
        GIT_EDITOR          = 'true'
        GIT_TERMINAL_PROMPT = '0'
        GIT_ASKPASS         = ''
        GCM_INTERACTIVE     = 'never'
    }

    # Without it, git for Windows skips a folder past 260 characters with a warning, and lists nothing in it.
    [string[]]$prefix = @('-c', 'core.longpaths=true')
    if ($RepoPath) {
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RepoPath)
        $prefix += @('-C', $resolved)
    }

    if ($RepoPath -or $NoRepository) {
        foreach ($name in Get-GitRepositoryVariable) {
            $environment[$name] = $null
        }
    }

    [string[]]$argv = $prefix + $Arguments

    if ($VerbosePreference -ne 'SilentlyContinue') {
        $words = @(
            foreach ($argument in $argv) {
                $masked = Hide-MaskedValue -Text $argument -Mask $Mask
                $word = Hide-UrlCredential -Text $masked
                if ($word -eq '' -or $word -match '\s') {
                    "'" + $word.Replace("'", "''") + "'"
                }
                else {
                    $word
                }
            }
        )

        $maskedActivity = Hide-MaskedValue -Text $Activity -Mask $Mask
        Write-Verbose "$(Hide-UrlCredential -Text $maskedActivity): git $($words -join ' ')"
    }

    if (-not $Tolerant) {
        return Invoke-NativeCommand -Activity $Activity -Command 'git' -Arguments $argv `
            -Environment $environment -SeparateStderr -Mask $Mask -Verbose:$false
    }

    $read = Invoke-NativeRead -Command 'git' -Arguments $argv -Environment $environment -SeparateStderr `
        -Mask $Mask -Verbose:$false
    if (-not $read.Started) {
        $maskedActivity = Hide-MaskedValue -Text $Activity -Mask $Mask
        throw "$(Hide-UrlCredential -Text $maskedActivity) failed: git was not found on PATH."
    }

    # Each line is hidden on its own, so an @ on one cannot hide the others.
    $lines = @(@($read.Output) + @($read.ErrorOutput))
    $printed = @($lines | Hide-MaskedValue -Mask $Mask | Hide-UrlCredential)
    $read.Message = ($printed -join "`n").Trim()
    return $read
}
