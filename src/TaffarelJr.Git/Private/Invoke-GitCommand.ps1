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

        Every call also carries -c core.editor=true ahead of -Arguments,
        so nothing this module runs can ever block waiting on an
        interactive editor - a merge or commit that would otherwise open
        one completes using whatever default message git would have
        pre-filled.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
        Ignored when -Tolerant is set, since that path never throws.
    .PARAMETER Arguments
        Passed as an explicit array - a loose token like '-C' would
        otherwise bind as a PowerShell parameter instead of a git argument.
    .PARAMETER RepoPath
        The repo to run in, passed ahead of -Arguments as git's own -C so
        no directory is ever changed. Omit it to run against the current
        working directory.
    .PARAMETER Tolerant
        Returns a result object (Ok, ExitCode, Output) instead of
        throwing. For a call that uses a non-zero exit, or empty output,
        as its answer rather than as a failure.
    .OUTPUTS
        Without -Tolerant: the command's output lines, always an array.
        With -Tolerant: a hashtable (Ok, ExitCode, Output).
        Either way, a caller must never wrap the result in @() - that
        would nest the array instead of leaving it flat.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [string]$RepoPath,

        [switch]$Tolerant
    )

    [string[]]$prefix = if ($RepoPath) {
        @('-C', $RepoPath, '-c', 'core.editor=true')
    }
    else {
        @('-c', 'core.editor=true')
    }

    [string[]]$argv = $prefix + $Arguments

    if ($Tolerant) {
        return Invoke-NativeRead -Command 'git' -Arguments $argv
    }

    return Invoke-NativeCommand -Activity $Activity -Command 'git' -Arguments $argv
}
