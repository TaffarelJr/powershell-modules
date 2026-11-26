using namespace System.IO

function Write-FileByte {
    <#
    .SYNOPSIS
        Writes a byte order mark and some bytes over a file.
    .DESCRIPTION
        Not exported. The file is written in place rather than replaced, so it
        keeps its attributes: a hidden or system file stays one, and can be
        written at all. What is longer than the new bytes is cut off. A file
        that cannot be opened, because its folder is missing, another program
        holds it, or it is read-only, throws "Cannot write" with the path and
        the reason, before the file is changed. -CreateDirectory makes the
        folders on the way first.
    .PARAMETER Path
        The full path of the file.
    .PARAMETER Preamble
        The byte order mark, or no bytes.
    .PARAMETER Payload
        The encoded text.
    .PARAMETER CreateDirectory
        Makes any folder missing on the way to the file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]]$Preamble,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]]$Payload,

        [switch]$CreateDirectory
    )

    try {
        if ($CreateDirectory) {
            $null = [Directory]::CreateDirectory([Path]::GetDirectoryName($Path))
        }

        $stream = [File]::Open(
            $Path,
            [FileMode]::OpenOrCreate,
            [FileAccess]::Write,
            [FileShare]::Read)
    }
    catch {
        throw "Cannot write '$Path': $($_.Exception.GetBaseException().Message)"
    }

    try {
        $stream.Write($Preamble, 0, $Preamble.Length)
        $stream.Write($Payload, 0, $Payload.Length)
        $stream.SetLength($stream.Position)
    }
    finally {
        $stream.Dispose()
    }
}
