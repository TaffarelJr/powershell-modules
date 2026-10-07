function Get-GitUnmergedPath {
    <#
    .SYNOPSIS
        Returns each unmerged path a pathspec matches, relative to the
        repository root.
    .DESCRIPTION
        Read from the index, NUL-separated, so a path git would otherwise
        quote and escape comes back as the name on disk. Each path comes back
        once, however many conflict stages it has. A pathspec that matches no
        unmerged path returns nothing.
    .PARAMETER Pathspec
        The pathspec to match, as ConvertTo-GitPathspec builds it.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
    .PARAMETER RepoPath
        The folder git runs in. Omit it for PowerShell's current location.
    .OUTPUTS
        Each unmerged path, relative to the repository root.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseOutputTypeCorrectly',
        '',
        Justification = 'PowerShell unrolls the list this builds, so the output is its elements.')]
    param(
        [Parameter(Mandatory)]
        [string]$Pathspec,

        [Parameter(Mandatory)]
        [string]$Activity,

        [string]$RepoPath
    )

    $out = Invoke-GitCommand -Activity $Activity `
        -Arguments @('ls-files', '--unmerged', '--full-name', '-z', '--', $Pathspec) -RepoPath $RepoPath
    $entries = @(($out -join "`n") -split "`0" | Where-Object { $_ })

    # One entry per stage: '<mode> <hash> <stage>', a tab, then the path.
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $entries) {
        $path = $entry.Substring($entry.IndexOf("`t") + 1)
        if (-not $paths.Contains($path)) {
            $paths.Add($path)
        }
    }

    return $paths
}
