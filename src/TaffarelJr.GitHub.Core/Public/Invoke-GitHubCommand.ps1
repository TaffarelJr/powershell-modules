using namespace System.Collections.Generic

function Invoke-GitHubCommand {
    <#
    .SYNOPSIS
        Runs gh with its output captured and returns what it printed.
    .DESCRIPTION
        By default, throws on a non-zero exit. -Tolerant returns a result
        object instead, for a call whose failure is a meaningful answer
        rather than an error. Every TaffarelJr.GitHub.* module runs gh
        through here.

        Captured output is never a terminal, so gh does not prompt: a
        command that would have asked a question fails with a clear message
        instead, and colors, the pager, the spinner, and the update notice
        are all suppressed. gh's input is never the console either - with
        no -StdIn it is already at its end. What captured output does not
        stop is an editor: a gh command that wants one (gh gist edit with
        only --desc, say) still starts GH_EDITOR, core.editor, VISUAL, or
        EDITOR, and a real editor waits for ever. No function of these
        modules passes such a command; a caller who might can pin the
        editor with -Environment, as in the example.

        Output is stdout alone, so a warning on stderr - or the HTTP trace
        GH_DEBUG turns on - cannot end up in what a caller parses as JSON.
        Stderr still appears in a failure message. When gh answers a bad
        flag with its help, the message keeps only what it said before
        that: gh's whole help (the command's description, then USAGE) is
        cut at the blank line after the first paragraph, and a bare usage
        block (Usage:) at the blank line just above it.

        A failure message shows the activity, each argument, and each line
        gh printed with any credential a URL in it carries hidden by
        Hide-UrlCredential, so a token in a --repo URL or an endpoint
        is not shown, and any GitHub token printed on its own (ghp_, gho_,
        ghu_, ghs_, ghr_, github_pat_) hidden as well. Any other secret that
        is not part of a URL belongs in -StdIn, or is named in -Mask, which
        hides it as Hide-MaskedValue does: in the activity, in each argument,
        and in each line gh printed. The -Tolerant result keeps gh's output
        exactly as printed, and -Mask does not apply to it: run its Message
        through Hide-UrlCredential and Hide-MaskedValue before showing it,
        which hides a URL's credential and the values named, and leaves a
        token that stands alone.

        With -Verbose, the command line is written before gh runs, hidden
        as a failure message hides it, and never with the -StdIn text. The
        caller's -Verbose or $VerbosePreference is followed, also when a
        function of another module calls this.

        Authentication is gh's own - a stored login, or GH_TOKEN in the
        environment as in a GitHub Actions job. This module never handles
        a token itself.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
        Used only in a thrown message; with -Tolerant, that is only when
        gh cannot be found.
    .PARAMETER Argument
        Passed as an explicit array - a loose token like '-R' would
        otherwise bind as a PowerShell parameter instead of a gh argument.
        An empty-string element is allowed - PowerShell's own binder
        rejects one on a bare [string[]] parameter otherwise, even
        though the array itself is never null or empty. An element that
        is exactly '--' always ends gh's options, as it does for gh
        itself: a free-text flag value that is literally '--' belongs in
        the --flag=value form instead.
    .PARAMETER Repository
        The repository to target - [HOST/]OWNER/REPO, a URL, or a
        repository object, read as ConvertTo-GitHubRepositoryReference reads
        it - added as gh's own --repo: after the given arguments, or ahead
        of the first -- among them, which ends the options. A blank one
        throws. Omit it, or pass $null or an empty string as a caller does
        for a -Repository its own caller left out, to let gh infer the
        repository from the current directory's git remotes. Only for a
        subcommand that accepts --repo - a caller wrapping one that does
        not simply never passes it.
    .PARAMETER StdIn
        Piped to gh instead of appearing in its arguments, as UTF-8 with no
        byte-order mark, ended with one newline. For a value that must
        never reach the console - a secret, a token - since a failure
        message renders the whole argument vector.
    .PARAMETER Environment
        Variables set for this gh call alone, over a copy of this
        process's; a $null value removes one. gh is then run as a process
        of its own rather than through PowerShell's call operator, so it
        must be the gh executable - a function, alias, or script named gh
        is not run.
    .PARAMETER Tolerant
        Returns a result object instead of throwing. For a call that uses a
        non-zero exit as its answer rather than as a failure. Throws only
        when gh itself cannot be found.
    .PARAMETER Mask
        Values to hide wherever a message or the verbose line shows them: in
        the activity, in each argument, and in each line gh printed that a
        failure message quotes. Each is replaced by *** as Hide-MaskedValue
        does, so a value of fewer than four characters is ignored, and so is
        $null or an empty entry. It does not apply to the result of
        -Tolerant, which keeps gh's output as printed. Give a secret by
        variable: PowerShell's own error view quotes the line of the
        calling script, so a secret written in it is shown there.
    .INPUTS
        None
    .OUTPUTS
        System.String
        Without -Tolerant: gh's output, one line at a time. Wrap the call
        in @() to collect it as an array.
        System.Collections.Hashtable
        With -Tolerant: Ok, Started, ExitCode, TimedOut, Output and
        ErrorOutput (each a string[]), and Message, stdout and stderr
        together as one string, for an error to quote.
    .EXAMPLE
        $arguments = @('pr', 'list', '--json', 'number')
        $lines = Invoke-GitHubCommand -Activity 'Listing pull requests' `
            -Argument $arguments -Repository 'cli/cli'

        Runs gh pr list --json number --repo cli/cli and returns its JSON
        lines; a failure throws "Listing pull requests failed: gh pr list
        ... (exit 1)" with gh's own reason.
    .EXAMPLE
        $arguments = @('gist', 'edit', $id, '--desc', 'x')
        $noEditor = @{ GH_EDITOR = 'no-editor' }
        Invoke-GitHubCommand -Activity 'Editing the gist' -Argument $arguments `
            -Environment $noEditor

        Runs a gh command that may want an editor with one that does not
        exist, so gh fails at once instead of waiting on a window nobody
        sees.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.GitHub.Core/README.md
    #>
    [CmdletBinding()]
    [OutputType([string], [hashtable])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [Alias('Arguments')]
        [AllowEmptyString()]
        [string[]]$Argument,

        [AllowNull()]
        [object]$Repository,

        [string]$StdIn,

        [System.Collections.IDictionary]$Environment,

        [switch]$Tolerant,

        [string[]]$Mask
    )

    try {
        $ErrorActionPreference = 'Stop'

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference')
        }

        # $null and '' are how a caller passes on a -Repository its own caller left out.
        $reference = $null
        if ($null -ne $Repository -and $Repository -cne '') {
            $reference = ConvertTo-GitHubRepositoryReference -Repository $Repository
        }

        [string[]]$argv = $Argument
        if ($reference) {
            # Ahead of any --, which ends the options: after it gh would read --repo as an operand.
            $options = [array]::IndexOf($argv, '--')
            if ($options -lt 0) {
                $options = $argv.Count
            }

            $withRepository = [List[string]]::new($argv)
            $withRepository.InsertRange($options, [string[]]@('--repo', $reference))
            $argv = $withRepository.ToArray()
        }

        $extra = @{ SeparateStderr = $true }
        foreach ($name in 'StdIn', 'Environment') {
            if ($PSBoundParameters.ContainsKey($name)) {
                $extra[$name] = $PSBoundParameters[$name]
            }
        }

        # Quoted the way PowerShell reads it back, so an empty argument stays
        # visible and one holding a space is not mistaken for two.
        $words = foreach ($word in @('gh') + $argv) {
            $masked = Hide-MaskedValue -Text $word -Mask $Mask
            $shown = Hide-GitHubCredential -Text $masked
            if ($shown -match '^$|[\s''"]') {
                "'" + $shown.Replace("'", "''") + "'"
            }
            else {
                $shown
            }
        }

        $maskedActivity = Hide-MaskedValue -Text $Activity -Mask $Mask
        $shownActivity = Hide-GitHubCredential -Text $maskedActivity
        $withInput = if ($PSBoundParameters.ContainsKey('StdIn')) { ' (with standard input)' } else { '' }
        Write-Verbose "${shownActivity}: $($words -join ' ')$withInput"
        # The line above shows what ProcessInvocation's would, and hides a token that stands alone too.
        $read = Invoke-NativeRead -Command 'gh' -Arguments $argv @extra -Verbose:$false
        if (-not $read.Started) {
            throw "$shownActivity failed: gh was not found on PATH."
        }

        # gh follows a bad flag's reason with a blank line and its whole help -
        # the command's description, then USAGE - which would bury that reason. A
        # bare usage block (Usage:) follows the reason directly.
        $errors = [string[]]@($read.ErrorOutput)
        $usage = [array]::FindIndex($errors, [Predicate[string]]{ param($line) $line -cmatch '^(USAGE|Usage:)' })
        if ($usage -gt 0) {
            $cut = $usage - 1
            if ($errors[$usage] -ceq 'USAGE') {
                $reason = [array]::FindIndex($errors, [Predicate[string]]{ param($line) $line -ne '' })
                $blank = [array]::IndexOf($errors, '', $reason)
                if ($blank -ge 0 -and $blank -lt $usage) {
                    $cut = $blank
                }
            }

            if ($errors[$cut] -eq '') {
                $errors = $errors[0..$cut]
            }
        }

        $read.Message = ((@($read.Output) + $errors) -join "`n").Trim()
        if ($Tolerant -or $read.Ok) {
            if ($Tolerant) {
                return $read
            }

            return $read.Output
        }

        $message = "$shownActivity failed: $($words -join ' ') (exit $($read.ExitCode))"
        if ($read.Message) {
            $printed = @($read.Message -split "`n" | Hide-MaskedValue -Mask $Mask | Hide-GitHubCredential)
            $message += "`n$($printed -join "`n")"
        }

        throw $message
    }
    catch {
        $PSCmdlet.ThrowTerminatingError((ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
