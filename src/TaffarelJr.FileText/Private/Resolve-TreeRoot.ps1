function Resolve-TreeRoot {
    <#
    .SYNOPSIS
        Returns the full path of the folder a path argument names, resolved
        against PowerShell's current location.
    .DESCRIPTION
        Not exported. A relative path is relative to PowerShell's location,
        not the process's, and a path on a PowerShell drive comes back as the
        real file system path, as Resolve-TextFilePath does for a file. A
        wildcard character in the path is part of the name.
    .PARAMETER Path
        The path as the caller gave it.
    .OUTPUTS
        The full path. Throws when the path is blank, is not usable as a path
        at all, is on a drive that is not the file system, names a file, or
        names nothing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'The path is blank; give the path of a folder on disk.'
    }

    $provider = $null
    $drive = $null
    $isFolder = $false
    $isFile = $false
    try {
        $paths = $ExecutionContext.SessionState.Path
        $full = $paths.GetUnresolvedProviderPathFromPSPath(
            $Path, [ref]$provider, [ref]$drive)
        if ($provider.Name -eq 'FileSystem') {
            $isFolder = Test-Path -LiteralPath $full -PathType Container
            $isFile = Test-Path -LiteralPath $full -PathType Leaf
        }
    }
    catch {
        $reason = $_.Exception.GetBaseException().Message
        throw "'$Path' is not a usable folder path: $reason"
    }

    if ($provider.Name -ne 'FileSystem') {
        throw "'$Path' is not a file system path; give a folder on disk."
    }

    if ($isFile) {
        throw "'$Path' is a file, not a folder."
    }

    if (-not $isFolder) {
        throw "No such folder: '$Path'."
    }

    return $full
}
