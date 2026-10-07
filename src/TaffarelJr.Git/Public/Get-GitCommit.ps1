function Get-GitCommit {
    <#
    .SYNOPSIS
        Returns one commit's details, or $null when the ref does not
        resolve to a commit.
    .PARAMETER Ref
        The commit to describe. Defaults to HEAD.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .OUTPUTS
        See Get-GitLog - the same shape, for exactly one commit.
    #>
    param(
        [string]$Ref = 'HEAD',

        [string]$RepoPath
    )

    # Checked first, rather than letting Get-GitLog's own git log call fail:
    # an invalid range throws there, where $null is the expected answer here.
    if (-not (Resolve-GitRef -Ref $Ref -RepoPath $RepoPath)) {
        return $null
    }

    $result = Get-GitLog -Range $Ref -Count 1 -RepoPath $RepoPath
    if ($result.Count -eq 0) {
        return $null
    }

    return $result[0]
}
