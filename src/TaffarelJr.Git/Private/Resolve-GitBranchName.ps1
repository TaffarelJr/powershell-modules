function Resolve-GitBranchName {
    <#
    .SYNOPSIS
        Returns the short name of the local branch a name stands for, or
        throws when it stands for none.
    .DESCRIPTION
        A local branch of exactly that name wins, so a tag that shares it is
        never used in its place. Otherwise the name is read the way git reads
        a revision, so shorthand such as '@{-1}' (the previous branch), 'HEAD'
        and 'refs/heads/<name>' work too; a tag, a remote branch, a commit, a
        detached HEAD, or a file or folder of that name throws, saying what
        the name is instead.
    .PARAMETER Name
        The name to resolve.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
    .PARAMETER Hint
        What the caller can do instead, added to the message when the name
        stands for no local branch.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .OUTPUTS
        The branch's short name, without 'refs/heads/'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Activity,

        [string]$Hint,

        [string]$RepoPath
    )

    $exists = Invoke-GitCommand -Activity $Activity `
        -Arguments @('show-ref', '--verify', '--quiet', "refs/heads/$Name") -RepoPath $RepoPath -Tolerant
    if ($exists.ExitCode -gt 1) {
        throw "$Activity failed (exit $($exists.ExitCode)): $($exists.Message)"
    }

    if ($exists.Ok) {
        return $Name
    }

    # show-ref has read the repository, so --quiet's only failure left is
    # exit 1, for a name that is no revision at all.
    $read = Invoke-GitCommand -Activity $Activity `
        -Arguments @('rev-parse', '--verify', '--quiet', '--symbolic-full-name', $Name) -RepoPath $RepoPath -Tolerant

    # A range such as 'main..side' prints one line per end, and a form such as
    # 'side^!' prints the branch but fails: neither is a branch.
    $lines = @($read.Output | Where-Object { $_ })
    $full = if ($read.Ok -and $lines.Count -eq 1) { $lines[0].Trim() } else { '' }
    $prefix = 'refs/heads/'
    if ($full.StartsWith($prefix, [StringComparison]::Ordinal)) {
        return $full.Substring($prefix.Length)
    }

    $reason = if ($lines.Count -gt 1) {
        " ('$Name' names more than one revision)"
    }
    elseif (-not $read.Ok) {
        ''
    }
    elseif ($full -ceq 'HEAD') {
        " (HEAD is detached)"
    }
    elseif (-not $full) {
        " ('$Name' is a revision, not a branch)"
    }
    else {
        " ('$Name' is $full)"
    }

    $message = "$Activity failed: there is no branch named '$Name'$reason."
    if ($Hint) {
        $message += " $Hint"
    }

    throw $message
}
