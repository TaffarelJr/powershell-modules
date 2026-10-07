function ConvertTo-GitPathspec {
    <#
    .SYNOPSIS
        Turns a path into a git pathspec that names exactly that path.
    .DESCRIPTION
        A bare relative path, such as 'src/x.txt', is relative to the
        repository root, the way git reports paths, whichever folder git
        runs in; its inner '.' and '..' segments are resolved, and one that
        climbs above the root throws. A relative path that starts with '.'
        or '..', such as '.\x.txt' or '.', is relative to the folder git runs
        in, and is made absolute against it; so is a rooted path with no
        drive, such as '\x.txt', which on Windows names the root of that
        folder's drive. An absolute path is used as it is. Either way the
        path is literal: '*', '?' and '[' are parts of the name, not a
        pattern. Backslashes become forward slashes.
    .PARAMETER Path
        The path to convert.
    .PARAMETER Activity
        What was being attempted, as a phrase that reads before "failed".
    .PARAMETER RepoPath
        The folder git runs in, which a path starting with '.' or '..' is
        relative to. Omit it for PowerShell's current location.
    .OUTPUTS
        The pathspec - ':(top,literal)<path>' for a bare relative path, or
        ':(top)' when it comes to the root itself, and
        ':(literal)<absolute path>' for any other.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Activity,

        [string]$RepoPath
    )

    $full = Resolve-GitPath -Path $Path -RepoPath $RepoPath
    if ($full) {
        return ":(literal)$($full -replace '\\', '/')"
    }

    $rootPath = ConvertTo-GitRootPath -Path $Path -Activity $Activity
    if (-not $rootPath) {
        return ':(top)'
    }

    return ":(top,literal)$rootPath"
}
