using namespace System.IO

function Resolve-GitPath {
    <#
    .SYNOPSIS
        Returns the absolute form of a path that is not relative to the
        repository root, or nothing for one that is.
    .DESCRIPTION
        An absolute path comes back as it is, with forward slashes. A
        relative path that starts with '.' or '..' - '.', '.\x.txt',
        '../x.txt' - is relative to the folder git runs in, and comes back
        made absolute against it; so does a rooted path with no drive, such
        as '\x.txt', which on Windows names the root of that folder's drive.
        A bare relative path, such as 'src/x.txt', is relative to the
        repository root, the way git reports paths, and returns nothing. A
        backslash is read as a forward slash.

        A path qualified with its provider, as the PSPath property of
        Get-Item and Get-ChildItem output holds it, such as
        'Microsoft.PowerShell.Core\FileSystem::C:\src\x.txt', names the
        path after the '::' and is read as that one.
    .PARAMETER Path
        The path to resolve.
    .PARAMETER RepoPath
        The folder git runs in. A relative path or a PowerShell drive is
        resolved against PowerShell's current location first. Omit it for
        PowerShell's current location.
    .OUTPUTS
        The absolute path, or nothing for a bare relative path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$RepoPath
    )

    $named = $Path
    if ($Path -match '^(?:Microsoft\.PowerShell\.Core\\)?FileSystem::') {
        $named = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    }

    $slashed = $named -replace '\\', '/'
    if ([Path]::IsPathFullyQualified($slashed)) {
        return $slashed
    }

    if ($slashed -notmatch '^\.\.?(/|$)' -and -not [Path]::IsPathRooted($slashed)) {
        return
    }

    $base = if ($RepoPath) {
        $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RepoPath)
    }
    else {
        $ExecutionContext.SessionState.Path.CurrentFileSystemLocation.ProviderPath
    }

    return [Path]::GetFullPath($slashed, $base)
}
