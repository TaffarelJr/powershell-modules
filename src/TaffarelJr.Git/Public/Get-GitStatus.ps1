using namespace System.Collections.Generic

function Get-GitStatus {
    <#
    .SYNOPSIS
        Returns every changed path in the working tree, staged or not.
    .DESCRIPTION
        Read NUL-separated (-z), because git's default porcelain output
        quotes and C-escapes any path holding a space or a non-ASCII
        character - 'cafe.txt' with an accent arrives as an escaped octal
        sequence that names no file on disk, so a pathspec built from the
        default output can silently miss it. Untracked files are listed
        one by one (-uall) rather than folded into their directory, so an
        untracked folder that was already there cannot hide a file added
        inside it later.

        An empty result means a clean working tree.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .OUTPUTS
        One object per changed path: Status (git's two-letter porcelain
        code), Path, and OldPath - set only for a rename or copy, since
        git reports those as two paths for one change.
    #>
    param(
        [string]$RepoPath
    )

    $out = Invoke-GitCommand -Activity 'Reading the working tree status' `
        -Arguments @('status', '--porcelain', '-z', '-uall') -RepoPath $RepoPath
    $entries = @(($out -join '') -split "`0" | Where-Object { $_ })

    $results = [List[object]]::new()
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $entry = $entries[$i]
        if ($entry.Length -le 3) {
            continue
        }

        $code = $entry.Substring(0, 2)
        $path = $entry.Substring(3)
        $oldPath = $null

        # A rename or copy puts the original path in the NEXT entry, which
        # carries no status prefix of its own.
        if ($code -match '[RC]') {
            $i++
            if ($i -lt $entries.Count) {
                $oldPath = $entries[$i]
            }
        }

        $results.Add([PSCustomObject]@{
                Status  = $code
                Path    = $path
                OldPath = $oldPath
            })
    }

    return , @($results)
}
