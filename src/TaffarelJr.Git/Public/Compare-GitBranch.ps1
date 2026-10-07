function Compare-GitBranch {
    <#
    .SYNOPSIS
        Returns how many commits a branch is ahead and behind its
        upstream, or $null when that cannot be determined.
    .PARAMETER Branch
        The branch to compare. Defaults to the current branch.
    .PARAMETER Upstream
        The ref to compare it against. Defaults to -Branch's own
        configured upstream.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .OUTPUTS
        A single object: Ahead, Behind - both commit counts.
    #>
    param(
        [string]$Branch,

        [string]$Upstream,

        [string]$RepoPath
    )

    $ref = if ($Branch) { $Branch } else { Get-GitBranch -RepoPath $RepoPath }
    if (-not $ref) {
        return $null
    }

    $upstreamRef = if ($Upstream) { $Upstream } else { "$ref@{upstream}" }

    $read = Invoke-GitCommand -Activity 'Comparing branches' `
        -Arguments @('rev-list', '--left-right', '--count', "$ref...$upstreamRef") -RepoPath $RepoPath -Tolerant
    if (-not $read.Ok) {
        return $null
    }

    $parts = ($read.Output -join '').Trim() -split '\s+'
    if ($parts.Count -lt 2) {
        return $null
    }

    return [PSCustomObject]@{
        Ahead  = [int]$parts[0]
        Behind = [int]$parts[1]
    }
}
