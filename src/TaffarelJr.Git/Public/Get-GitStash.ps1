using namespace System.Collections.Generic

function Get-GitStash {
    <#
    .SYNOPSIS
        Returns every stashed entry.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .OUTPUTS
        One object per stash, newest first: Index (for Restore-GitStash),
        Message.
    #>
    param(
        [string]$RepoPath
    )

    $out = Invoke-GitCommand -Activity 'Listing stashes' `
        -Arguments @('stash', 'list', '--format=%gd%x1f%s') -RepoPath $RepoPath

    $results = [List[object]]::new()
    foreach ($line in $out) {
        $parts = $line -split "`u{1F}"
        if ($parts.Count -lt 2) {
            continue
        }

        if ($parts[0] -notmatch '\{(\d+)\}') {
            continue
        }

        $results.Add([PSCustomObject]@{
                Index   = [int]$Matches[1]
                Message = $parts[1]
            })
    }

    return , @($results)
}
