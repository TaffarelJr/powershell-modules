using namespace System.Management.Automation

function Resolve-TextFilePath {
    <#
    .SYNOPSIS
        Returns the full path a file argument names, resolved against
        PowerShell's current location.
    .DESCRIPTION
        Not exported. .NET resolves a relative path against the process's own
        working directory, which Set-Location does not change, so a relative
        path handed straight to [File] can read or write a different file from
        the one PowerShell's own commands see. A path on a PowerShell drive
        comes back as the real file system path. A path on a drive of another
        provider - Env:, Variable:, HKCU: - is refused: what comes back for it
        is the provider's own name for the item, which [File] would take as a
        relative path and write in the process's working directory.
    .PARAMETER Path
        The path as the caller gave it.
    .PARAMETER MustExist
        Throws when there is no such file.
    .OUTPUTS
        The full path. Throws when it is blank, which PowerShell would resolve
        to the current folder; names a folder; is not on the file system;
        names a drive or provider that does not exist; or is not a usable
        path at all - one that climbs above its drive root, holds a NUL
        character, or is too long - giving the reason.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$MustExist
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'The path is blank; give the path of a file on disk.'
    }

    $provider = $null
    $drive = $null
    $isFolder = $false
    $isFile = $false
    try {
        $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            $Path,
            [ref]$provider,
            [ref]$drive)
        if ($provider.Name -eq 'FileSystem') {
            $isFolder = Test-Path -LiteralPath $full -PathType Container
            $isFile = Test-Path -LiteralPath $full -PathType Leaf
        }
    }
    catch [DriveNotFoundException], [ProviderNotFoundException] {
        throw "'$Path' is not a path on any drive or provider here; give the path of a file on disk."
    }
    catch {
        throw "'$Path' is not a usable file path: $($_.Exception.GetBaseException().Message)"
    }

    if ($provider.Name -ne 'FileSystem') {
        throw "'$Path' is not a file system path; give the path of a file on disk."
    }

    if ($isFolder) {
        throw "'$Path' is a folder, not a file."
    }

    if ($MustExist -and -not $isFile) {
        throw "No such file: '$Path'."
    }

    return $full
}
