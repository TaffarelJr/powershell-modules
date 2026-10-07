function Test-GitRepository {
    <#
    .SYNOPSIS
        Returns whether a path is inside a git working tree.
    .PARAMETER RepoPath
        The path to check. Omit it to check the current working directory.
    #>
    param(
        [string]$RepoPath
    )

    $read = Invoke-GitCommand -Activity 'Checking for a git repository' `
        -Arguments @('rev-parse', '--is-inside-work-tree') -RepoPath $RepoPath -Tolerant
    return $read.Ok
}
