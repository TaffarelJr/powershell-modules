function Assert-GitOwnershipTrusted {
    <#
    .SYNOPSIS
        Throws when a git command failed only because git refuses to use a
        repository that another user owns.
    .DESCRIPTION
        For a function whose answer to a failed command is "not a
        repository": git also refuses a repository owned by someone else
        (its safe.directory check, routine in a CI container), and that
        repository must not read as missing. The command is run again with
        every directory trusted for that one call; if it then works, the
        refusal was the reason. That holds in any language git speaks,
        where its message would not. A folder that does not exist cannot
        be a repository at all, and is not asked about twice.

        git honors safe.directory given on the command line from 2.38 on;
        an older git that refuses the repository refuses it here too, so
        the repository reads as missing.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
    .PARAMETER Arguments
        The git arguments that failed.
    .PARAMETER Message
        What git said when they failed, for the thrown message.
    .PARAMETER RepoPath
        The repo the command ran in.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Activity,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [string]$RepoPath
    )

    if ($RepoPath) {
        $folder = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RepoPath)
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            return
        }
    }

    $trusted = Invoke-GitCommand -Activity $Activity -Arguments (@('-c', 'safe.directory=*') + $Arguments) `
        -RepoPath $RepoPath -Tolerant
    if ($trusted.Ok) {
        throw "$Activity failed: git refuses to use a repository another user owns. $Message"
    }
}
