function ConvertTo-GitRootPath {
    <#
    .SYNOPSIS
        Normalizes a path relative to the repository root, the way git would
        read it without its literal magic.
    .DESCRIPTION
        A backslash is read as a forward slash; empty and '.' segments are
        dropped, and each '..' takes back the segment before it. A '..' that
        would climb above the root throws, rather than naming a path nothing
        in the repository can match.
    .PARAMETER Path
        The path, relative to the repository root.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
    .OUTPUTS
        The normalized path with forward slashes, or an empty string for the
        root itself.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Activity
    )

    $segments = [System.Collections.Generic.List[string]]::new()
    foreach ($segment in ($Path -replace '\\', '/') -split '/') {
        if ($segment -eq '' -or $segment -eq '.') {
            continue
        }

        if ($segment -eq '..') {
            if ($segments.Count -eq 0) {
                throw "$Activity failed: -Path '$Path' climbs above the repository root." +
                " A path relative to the folder this runs in starts with '.' or '..'."
            }

            $segments.RemoveAt($segments.Count - 1)
            continue
        }

        $segments.Add($segment)
    }

    return $segments -join '/'
}
