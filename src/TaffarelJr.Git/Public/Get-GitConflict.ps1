function Get-GitConflict {
    <#
    .SYNOPSIS
        Returns every currently-conflicted path, during a merge, rebase,
        or cherry-pick.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    param(
        [string]$RepoPath
    )

    return Invoke-GitCommand -Activity 'Reading conflicted paths' `
        -Arguments @('diff', '--name-only', '--diff-filter=U') -RepoPath $RepoPath
}
