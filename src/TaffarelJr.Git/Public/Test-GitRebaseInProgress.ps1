function Test-GitRebaseInProgress {
    <#
    .SYNOPSIS
        Returns whether a rebase is currently paused on a conflict.
    .PARAMETER RepoPath
        The repo to check. Omit it to use the current working directory.
    #>
    param(
        [string]$RepoPath
    )

    $gitDir = Get-GitDirectory -RepoPath $RepoPath
    if (-not $gitDir) {
        return $false
    }

    foreach ($marker in 'rebase-merge', 'rebase-apply') {
        if (Test-Path -LiteralPath (Join-Path $gitDir $marker) -PathType Container) {
            return $true
        }
    }

    return $false
}
