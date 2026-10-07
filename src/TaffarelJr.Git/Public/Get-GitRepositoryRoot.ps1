function Get-GitRepositoryRoot {
    <#
    .SYNOPSIS
        Returns a repo's top-level working directory, or $null when the
        path is not inside a git repository.
    .PARAMETER RepoPath
        The path to resolve from. Omit it to resolve from the current
        working directory.
    #>
    param(
        [string]$RepoPath
    )

    $read = Invoke-GitCommand -Activity 'Finding the repository root' `
        -Arguments @('rev-parse', '--show-toplevel') -RepoPath $RepoPath -Tolerant
    if (-not $read.Ok) {
        return $null
    }

    return ($read.Output -join '').Trim()
}
