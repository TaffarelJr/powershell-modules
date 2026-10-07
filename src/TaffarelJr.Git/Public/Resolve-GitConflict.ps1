function Resolve-GitConflict {
    <#
    .SYNOPSIS
        Resolves a conflicted path by keeping one side whole, then marks
        it resolved.
    .DESCRIPTION
        Checking out a side alone only updates the working tree; git
        still considers the path unmerged until it is re-staged. This
        does both steps, so the path is fully resolved afterward.
    .PARAMETER Path
        The conflicted path to resolve.
    .PARAMETER Side
        Which side to keep: Ours (the branch being merged/rebased into)
        or Theirs (the branch being brought in).
    .PARAMETER RepoPath
        The repo to act in. Omit it to use the current working directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('Ours', 'Theirs')]
        [string]$Side,

        [string]$RepoPath
    )

    $flag = "--$($Side.ToLowerInvariant())"
    Invoke-GitCommand -Activity "Keeping the $Side side of $Path" `
        -Arguments @('checkout', $flag, '--', $Path) -RepoPath $RepoPath | Out-Null
    Add-GitChange -Path $Path -RepoPath $RepoPath
}
