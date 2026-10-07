function Get-GitDirectory {
    <#
    .SYNOPSIS
        Returns a repo's absolute .git directory, or $null when the path
        is not inside a git repository.
    .DESCRIPTION
        Asked of git rather than assumed to be '<root>/.git' - a worktree
        or submodule's git directory is a FILE pointing elsewhere, not a
        folder at that path.
    .PARAMETER RepoPath
        The path to resolve from. Omit it to resolve from the current
        working directory.
    #>
    param(
        [string]$RepoPath
    )

    $read = Invoke-GitCommand -Activity 'Finding the git directory' `
        -Arguments @('rev-parse', '--absolute-git-dir') -RepoPath $RepoPath -Tolerant
    if (-not $read.Ok) {
        return $null
    }

    return ($read.Output -join '').Trim()
}
