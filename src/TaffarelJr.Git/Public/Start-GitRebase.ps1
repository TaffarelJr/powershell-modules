function Start-GitRebase {
    <#
    .SYNOPSIS
        Starts replaying the current branch's commits onto another ref.
    .DESCRIPTION
        Not interactive - this is for rebasing onto a different base, not
        for reordering or squashing commits by hand. A conflict leaves the
        rebase paused; check Test-GitRebaseInProgress, resolve the
        conflicted paths (Get-GitConflict, Resolve-GitConflict), stage
        them, and call Resume-GitRebase - or Stop-GitRebase to abandon it.
    .PARAMETER Ref
        The ref to rebase onto.
    .PARAMETER RepoPath
        The repo to rebase in. Omit it to use the current working
        directory.
    .OUTPUTS
        A single object: Conflict ($false when the rebase finished
        cleanly).
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Ref,

        [string]$RepoPath
    )

    $read = Invoke-GitCommand -Activity "Rebasing onto $Ref" `
        -Arguments @('rebase', $Ref) -RepoPath $RepoPath -Tolerant
    if ($read.Ok) {
        return [PSCustomObject]@{ Conflict = $false }
    }

    if (Test-GitRebaseInProgress -RepoPath $RepoPath) {
        return [PSCustomObject]@{ Conflict = $true; Paths = (Get-GitConflict -RepoPath $RepoPath) }
    }

    throw "Rebasing onto $Ref failed: $($read.Output -join "`n")"
}
