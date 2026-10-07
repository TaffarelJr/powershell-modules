function Resume-GitRebase {
    <#
    .SYNOPSIS
        Continues a rebase that paused on a conflict, once every
        conflicted path has been resolved and staged.
    .PARAMETER RepoPath
        The repo to act in. Omit it to use the current working directory.
    .OUTPUTS
        A single object: Conflict ($false when the rebase finished).
    #>
    param(
        [string]$RepoPath
    )

    $read = Invoke-GitCommand -Activity 'Continuing the rebase' `
        -Arguments @('rebase', '--continue') -RepoPath $RepoPath -Tolerant
    if ($read.Ok) {
        return [PSCustomObject]@{ Conflict = $false }
    }

    if (Test-GitRebaseInProgress -RepoPath $RepoPath) {
        return [PSCustomObject]@{ Conflict = $true; Paths = (Get-GitConflict -RepoPath $RepoPath) }
    }

    throw "Continuing the rebase failed: $($read.Output -join "`n")"
}
