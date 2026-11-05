function Resolve-GitHubEnvFile {
    <#
    .SYNOPSIS
        Returns the full path of a dotenv file gh is to read, or throws
        when it is not a file or starts with a byte-order mark.
    .DESCRIPTION
        The path is resolved by Resolve-GitHubInputFile. gh's dotenv
        parser reads a UTF-8 byte-order mark as part of the first name and
        refuses the file with a message about an unexpected character, and
        it reads only UTF-8, so a UTF-16 file fails just as cryptically. A
        file starting with either mark is refused here, saying why.
    .PARAMETER Path
        The path as the caller gave it to -EnvFile.
    .OUTPUTS
        The full path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $full = Resolve-GitHubInputFile -Path $Path -Name 'EnvFile'
    $shown = Hide-UrlCredential -Text $Path
    $start = [byte[]]::new(3)
    $stream = [System.IO.File]::OpenRead($full)
    try {
        $read = $stream.Read($start, 0, 3)
    }
    finally {
        $stream.Dispose()
    }

    if ($read -eq 3 -and $start[0] -eq 0xEF -and $start[1] -eq 0xBB -and $start[2] -eq 0xBF) {
        throw "-EnvFile '$shown' starts with a UTF-8 byte-order mark, which gh reads as part of the first" +
        ' name: save the file without one.'
    }

    $utf16 = ($start[0] -eq 0xFF -and $start[1] -eq 0xFE) -or ($start[0] -eq 0xFE -and $start[1] -eq 0xFF)
    if ($read -ge 2 -and $utf16) {
        throw "-EnvFile '$shown' starts with a UTF-16 byte-order mark, and gh reads only UTF-8: save the file" +
        ' as UTF-8 without a byte-order mark.'
    }

    return $full
}
