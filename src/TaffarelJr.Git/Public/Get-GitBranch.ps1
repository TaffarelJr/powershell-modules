function Get-GitBranch {
    <#
    .SYNOPSIS
        Returns the current branch name, or every local branch with -List.
    .PARAMETER List
        Returns every local branch name instead of just the current one.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    param(
        [switch]$List,

        [string]$RepoPath
    )

    if ($List) {
        return Invoke-GitCommand -Activity 'Listing branches' `
            -Arguments @('branch', '--format=%(refname:short)') -RepoPath $RepoPath
    }

    $read = Invoke-GitCommand -Activity 'Reading the current branch' `
        -Arguments @('rev-parse', '--abbrev-ref', 'HEAD') -RepoPath $RepoPath -Tolerant
    if (-not $read.Ok) {
        return $null
    }

    return ($read.Output -join '').Trim()
}
