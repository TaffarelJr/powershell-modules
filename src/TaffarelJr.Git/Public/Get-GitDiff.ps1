function Get-GitDiff {
    <#
    .SYNOPSIS
        Returns a diff, as patch text by default or a path listing with
        -NameOnly/-NameStatus.
    .PARAMETER FromRef
        The earlier side of the comparison. Omit both -FromRef and -ToRef
        to compare the working tree (or the index, with -Staged) against
        HEAD.
    .PARAMETER ToRef
        The later side of the comparison.
    .PARAMETER Staged
        Compares the index instead of the working tree.
    .PARAMETER Path
        Scopes the diff to one path.
    .PARAMETER NameOnly
        Returns just the changed paths, one per line.
    .PARAMETER NameStatus
        Returns each changed path with its status letter (A/M/D/R/...).
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    param(
        [string]$FromRef,

        [string]$ToRef,

        [switch]$Staged,

        [string]$Path,

        [switch]$NameOnly,

        [switch]$NameStatus,

        [string]$RepoPath
    )

    $arguments = @('diff')
    if ($Staged) {
        $arguments += '--cached'
    }

    if ($NameOnly) {
        $arguments += '--name-only'
    }
    elseif ($NameStatus) {
        $arguments += '--name-status'
    }

    if ($FromRef) {
        $arguments += $FromRef
    }

    if ($ToRef) {
        $arguments += $ToRef
    }

    if ($Path) {
        $arguments += @('--', $Path)
    }

    return Invoke-GitCommand -Activity 'Reading the diff' -Arguments $arguments -RepoPath $RepoPath
}
