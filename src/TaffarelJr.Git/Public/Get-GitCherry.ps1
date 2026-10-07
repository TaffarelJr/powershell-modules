using namespace System.Collections.Generic

function Get-GitCherry {
    <#
    .SYNOPSIS
        Compares two branches by patch content rather than commit SHA,
        and returns which of -Upstream's commits -Base is still missing.
    .DESCRIPTION
        Immune to a prior rebase changing commit SHAs, unlike
        Compare-GitBranch - a commit already applied under a different
        SHA (because -Upstream was rebased since) is correctly reported
        as already present, not as missing.
    .PARAMETER Base
        The branch to check for missing commits.
    .PARAMETER Upstream
        The branch whose commits -Base should already have.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    .OUTPUTS
        One object per commit in -Upstream: Hash, Status - '+' when
        -Base is missing its patch, '-' when an equivalent patch is
        already there.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Base,

        [Parameter(Mandatory, Position = 1)]
        [string]$Upstream,

        [string]$RepoPath
    )

    $out = Invoke-GitCommand -Activity 'Comparing patches' `
        -Arguments @('cherry', $Base, $Upstream) -RepoPath $RepoPath

    $results = [List[object]]::new()
    foreach ($line in $out) {
        if ($line -notmatch '^([+-])\s+([0-9a-f]+)') {
            continue
        }

        $results.Add([PSCustomObject]@{
                Status = $Matches[1]
                Hash   = $Matches[2]
            })
    }

    return , @($results)
}
