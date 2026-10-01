using namespace System.IO

function Read-TextFile {
    <#
    .SYNOPSIS
        Reads a text file's content, encoding, and line ending,
        so a rewrite can preserve all three.
    .PARAMETER Path
        The file to read.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    $content = [File]::ReadAllText($Path)
    return [PSCustomObject]@{
        Content    = $content
        Encoding   = Get-FileEncoding -Path $Path
        LineEnding = Get-LineEnding -Content $content
    }
}
