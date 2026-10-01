using namespace System.IO
using namespace System.Text

function Get-FileEncoding {
    <#
    .SYNOPSIS
        Returns the encoding a file is written in,
        from the byte order mark it currently starts with.
    .DESCRIPTION
        Rewriting a file through PowerShell's own defaults is lossy:
        Set-Content writes UTF-8 without a BOM,
        so a file that had one loses it,
        and a UTF-16 file is silently transcoded.
        Reading the mark and handing it back
        keeps a content edit to just the content.

        UTF-8 without a BOM is the fallback,
        which is also what .NET assumes when it decodes.
    .PARAMETER Path
        The file to inspect.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $bom = [byte[]]::new(3)
    $stream = [File]::OpenRead($Path)
    try {
        $read = $stream.Read($bom, 0, 3)
    }
    finally {
        $stream.Dispose()
    }

    if ($read -ge 3 -and $bom[0] -eq 0xEF -and $bom[1] -eq 0xBB -and $bom[2] -eq 0xBF) {
        return [UTF8Encoding]::new($true)
    }

    if ($read -ge 2 -and $bom[0] -eq 0xFF -and $bom[1] -eq 0xFE) {
        return [UnicodeEncoding]::new($false, $true)
    }

    if ($read -ge 2 -and $bom[0] -eq 0xFE -and $bom[1] -eq 0xFF) {
        return [UnicodeEncoding]::new($true, $true)
    }

    return [UTF8Encoding]::new($false)
}
