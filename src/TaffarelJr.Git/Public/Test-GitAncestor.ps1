function Test-GitAncestor {
    <#
    .SYNOPSIS
        Returns whether one ref is an ancestor of another (or the same
        commit).
    .PARAMETER Ancestor
        The ref that might be the ancestor.
    .PARAMETER Descendant
        The ref that might descend from it.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Ancestor,

        [Parameter(Mandatory, Position = 1)]
        [string]$Descendant,

        [string]$RepoPath
    )

    $read = Invoke-GitCommand -Activity 'Checking ancestry' `
        -Arguments @('merge-base', '--is-ancestor', $Ancestor, $Descendant) -RepoPath $RepoPath -Tolerant
    return $read.Ok
}
