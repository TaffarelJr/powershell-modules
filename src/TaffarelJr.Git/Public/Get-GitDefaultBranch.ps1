function Get-GitDefaultBranch {
    <#
    .SYNOPSIS
        Returns a remote's default branch name, or $null when it cannot
        be determined.
    .DESCRIPTION
        Reads the remote's own HEAD symlink rather than assuming 'main' or
        'master', so a caller never has to hard-code either. That ref is
        set by a fresh clone, but a shallow or partial fetch of just one
        branch may not have it - this falls back to asking the remote
        directly (git remote show) when it is missing, at the cost of
        that one call reaching the network.
    .PARAMETER Name
        The remote to ask. Defaults to 'origin'.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    param(
        [string]$Name = 'origin',

        [string]$RepoPath
    )

    $read = Invoke-GitCommand -Activity 'Reading the default branch' `
        -Arguments @('symbolic-ref', "refs/remotes/$Name/HEAD") -RepoPath $RepoPath -Tolerant
    if ($read.Ok) {
        $ref = ($read.Output -join '').Trim()
        $prefix = "refs/remotes/$Name/"
        if ($ref.StartsWith($prefix)) {
            return $ref.Substring($prefix.Length)
        }
    }

    $show = Invoke-GitCommand -Activity "Asking $Name for its default branch" `
        -Arguments @('remote', 'show', $Name) -RepoPath $RepoPath -Tolerant
    if (-not $show.Ok) {
        return $null
    }

    foreach ($line in $show.Output) {
        if ($line -match 'HEAD branch:\s*(\S+)') {
            # A remote whose own HEAD was never pointed at a branch (common
            # for a freshly-created bare repo) reports this exact word
            # instead of a name - not a real branch to return.
            if ($Matches[1] -eq '(unknown)') {
                return $null
            }

            return $Matches[1]
        }
    }

    return $null
}
