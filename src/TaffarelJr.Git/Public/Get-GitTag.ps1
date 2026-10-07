using namespace System.Management.Automation

function Get-GitTag {
    <#
    .SYNOPSIS
        Returns tag names, optionally filtered and version-sorted.
    .PARAMETER Pattern
        A glob pattern, such as 'v*', to filter tag names by. Omit it to
        list every tag.
    .PARAMETER SortByVersion
        Sorts the result newest-first by semantic version, skipping any
        tag name that is not a valid version, instead of git's own
        creation-order default. Strips a leading 'v' before parsing, so
        'v1.2.3' sorts correctly too.
    .PARAMETER RepoPath
        The repo to read. Omit it to use the current working directory.
    #>
    param(
        [string]$Pattern,

        [switch]$SortByVersion,

        [string]$RepoPath
    )

    $arguments = @('tag', '--list')
    if ($Pattern) {
        $arguments += $Pattern
    }

    if (-not $SortByVersion) {
        return Invoke-GitCommand -Activity 'Listing tags' -Arguments $arguments -RepoPath $RepoPath
    }

    $tags = Invoke-GitCommand -Activity 'Listing tags' -Arguments $arguments -RepoPath $RepoPath
    $parsed = foreach ($tag in $tags) {
        $version = $null
        if ([SemanticVersion]::TryParse($tag.TrimStart('v'), [ref]$version)) {
            [PSCustomObject]@{ Tag = $tag; Version = $version }
        }
    }

    return , @($parsed | Sort-Object -Property Version -Descending | Select-Object -ExpandProperty Tag)
}
