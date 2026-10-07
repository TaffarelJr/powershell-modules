function Stop-GitRebase {
    <#
    .SYNOPSIS
        Abandons an in-progress rebase, restoring the branch to where it
        was before Start-GitRebase.
    .PARAMETER RepoPath
        The repo to act in. Omit it to use the current working directory.
    #>
    param(
        [string]$RepoPath
    )

    Invoke-GitCommand -Activity 'Aborting the rebase' `
        -Arguments @('rebase', '--abort') -RepoPath $RepoPath | Out-Null
}
