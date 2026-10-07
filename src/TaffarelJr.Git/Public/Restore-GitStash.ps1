function Restore-GitStash {
    <#
    .SYNOPSIS
        Restores a stash and removes it from the stash list.
    .PARAMETER Index
        Which stash to restore, where 0 is the most recently saved.
        Defaults to 0.
    .PARAMETER RepoPath
        The repo to restore into. Omit it to use the current working
        directory.
    #>
    param(
        [int]$Index = 0,

        [string]$RepoPath
    )

    Invoke-GitCommand -Activity 'Restoring the stash' `
        -Arguments @('stash', 'pop', "stash@{$Index}") -RepoPath $RepoPath | Out-Null
}
