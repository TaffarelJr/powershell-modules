using namespace System.Collections.Generic

function Get-GitRename {
    <#
    .SYNOPSIS
        Returns every file renamed between two refs, as old/new path
        pairs.
    .DESCRIPTION
        A rename detected by content similarity, not by name alone. A
        step that reacts to a deleted path should check this before
        treating it as a real deletion - otherwise a plain rename reads as
        a delete-and-add, which for a generated or synced file can mean
        silently dropping it on the deleted side instead of carrying it
        forward under its new name.
    .PARAMETER FromRef
        The earlier ref.
    .PARAMETER ToRef
        The later ref.
    .PARAMETER Path
        Scopes the comparison to one path.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .OUTPUTS
        One object per rename: OldPath, NewPath.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$FromRef,

        [Parameter(Mandatory, Position = 1)]
        [string]$ToRef,

        [string]$Path,

        [string]$RepoPath
    )

    $arguments = @('diff', '--name-status', '-M', '--diff-filter=R', $FromRef, $ToRef)
    if ($Path) {
        $arguments += @('--', $Path)
    }

    $out = Invoke-GitCommand -Activity 'Reading renames' -Arguments $arguments -RepoPath $RepoPath

    $results = [List[object]]::new()
    foreach ($line in $out) {
        $parts = $line -split "`t"
        if ($parts.Count -lt 3) {
            continue
        }

        $results.Add([PSCustomObject]@{
                OldPath = $parts[1]
                NewPath = $parts[2]
            })
    }

    return , @($results)
}
