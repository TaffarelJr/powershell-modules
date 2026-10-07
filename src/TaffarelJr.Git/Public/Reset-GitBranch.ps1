function Reset-GitBranch {
    <#
    .SYNOPSIS
        Moves the current branch to a different commit.
    .PARAMETER Ref
        Where to move the branch to. Defaults to HEAD, which resets
        without moving the branch - useful for just un-staging everything
        with the default -Mode.
    .PARAMETER Mode
        Soft leaves the working tree and index untouched, so everything
        since -Ref becomes staged again. Mixed (the default, matching
        git's own) also un-stages, leaving the working tree alone. Hard
        discards uncommitted changes entirely - the one genuinely
        destructive option here, since nothing after this can recover
        them.
    .PARAMETER RepoPath
        The repo to reset. Omit it to use the current working directory.
    #>
    param(
        [string]$Ref = 'HEAD',

        [ValidateSet('Soft', 'Mixed', 'Hard')]
        [string]$Mode = 'Mixed',

        [string]$RepoPath
    )

    $flag = "--$($Mode.ToLowerInvariant())"
    Invoke-GitCommand -Activity "Resetting to $Ref" -Arguments @('reset', $flag, $Ref) `
        -RepoPath $RepoPath | Out-Null
}
