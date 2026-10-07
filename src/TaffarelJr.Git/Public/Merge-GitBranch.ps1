function Merge-GitBranch {
    <#
    .SYNOPSIS
        Merges a ref into the current branch.
    .PARAMETER Ref
        The ref to merge in.
    .PARAMETER NoFastForward
        Always creates a merge commit, even when the current branch could
        simply fast-forward.
    .PARAMETER RepoPath
        The repo to merge in. Omit it to use the current working
        directory.
    .OUTPUTS
        A single object: Conflict ($false on a clean merge) and, only
        when it is $true, Paths - the conflicted files from
        Get-GitConflict, left for the caller to resolve.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Ref,

        [switch]$NoFastForward,

        [string]$RepoPath
    )

    $arguments = @('merge', '--no-edit')
    if ($NoFastForward) {
        $arguments += '--no-ff'
    }

    $arguments += $Ref

    $read = Invoke-GitCommand -Activity "Merging $Ref" -Arguments $arguments -RepoPath $RepoPath -Tolerant
    if ($read.Ok) {
        return [PSCustomObject]@{ Conflict = $false }
    }

    $conflicts = Get-GitConflict -RepoPath $RepoPath
    if ($conflicts.Count -gt 0) {
        return [PSCustomObject]@{ Conflict = $true; Paths = $conflicts }
    }

    throw "Merging $Ref failed: $($read.Output -join "`n")"
}
