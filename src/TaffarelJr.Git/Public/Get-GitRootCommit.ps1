function Get-GitRootCommit {
    <#
    .SYNOPSIS
        Returns a repo's root commit SHA(s) - the history's starting
        point(s), reached by following every parent to its end.
    .DESCRIPTION
        Usually a single commit, but a history merged from unrelated
        starting points has more than one; every one of them is returned.
    .PARAMETER Ref
        Where to start walking history backward from. Defaults to HEAD.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    param(
        [string]$Ref = 'HEAD',

        [string]$RepoPath
    )

    return Invoke-GitCommand -Activity 'Finding the root commit' `
        -Arguments @('rev-list', '--max-parents=0', $Ref) -RepoPath $RepoPath
}
