function Invoke-GitHubCommand {
    <#
    .SYNOPSIS
        Runs gh with its output captured - the only function in this
        module that calls TaffarelJr.ProcessInvocation.
    .DESCRIPTION
        By default, throws on a non-zero exit, like Invoke-NativeCommand.
        -Tolerant switches to Invoke-NativeRead's shape instead: a result
        object rather than a throw, for a call whose failure is a
        meaningful answer rather than an error.

        Captured output is never a terminal, and gh treats that as
        non-interactive on its own: a command that would have prompted
        fails with a clear message instead, and colors, the pager, the
        spinner, and the update notice are all suppressed. Nothing here
        needs to pin an environment variable to get that behavior.

        Authentication is gh's own - a stored login, or GH_TOKEN in the
        environment as in a GitHub Actions job. This module never handles
        a token itself.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
        Ignored when -Tolerant is set, since that path never throws.
    .PARAMETER Arguments
        Passed as an explicit array - a loose token like '-R' would
        otherwise bind as a PowerShell parameter instead of a gh argument.
    .PARAMETER Repository
        The repository to target, in [HOST/]OWNER/REPO form, appended as
        gh's own --repo. Omit it to let gh infer the repository from the
        current directory's git remotes. Only for a subcommand that
        accepts --repo - a caller wrapping one that does not simply never
        passes it.
    .PARAMETER StdIn
        Piped to gh instead of appearing in its arguments. For a value
        that must never reach the console - a secret, a token - since a
        failure message renders the whole argument vector. Not combined
        with -Tolerant.
    .PARAMETER Tolerant
        Returns a result object (Ok, ExitCode, Output) instead of
        throwing. For a call that uses a non-zero exit as its answer
        rather than as a failure.
    .OUTPUTS
        Without -Tolerant: gh's output lines, always an array.
        With -Tolerant: a hashtable (Ok, ExitCode, Output).
        Either way, a caller must never wrap the result in @() - that
        would nest the array instead of leaving it flat.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [string]$Repository,

        [string]$StdIn,

        [switch]$Tolerant
    )

    [string[]]$argv = $Arguments
    if ($Repository) {
        $argv += @('--repo', $Repository)
    }

    if ($Tolerant) {
        return Invoke-NativeRead -Command 'gh' -Arguments $argv
    }

    $extra = @{}
    if ($PSBoundParameters.ContainsKey('StdIn')) {
        $extra['StdIn'] = $StdIn
    }

    return Invoke-NativeCommand -Activity $Activity -Command 'gh' -Arguments $argv @extra
}
