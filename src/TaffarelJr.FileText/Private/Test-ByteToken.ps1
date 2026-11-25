using namespace System.IO
using namespace System.Text

function Test-ByteToken {
    <#
    .SYNOPSIS
        Says whether a file's bytes hold a token written in UTF-8, UTF-16, or
        UTF-32, in either byte order.
    .DESCRIPTION
        Not exported. For content that is not going to be decoded as text.
        The file is read a chunk at a time, so its size does not matter, and
        each chunk is searched as Latin-1 for the token's patterns. Each chunk
        is searched together with the end of the one before it, so a token
        split across two reads is still found.
    .PARAMETER Path
        The full path of the file, as Resolve-TextFilePath returns it.
    .PARAMETER Token
        The text to look for.
    .PARAMETER ChunkSize
        How many bytes to read at a time.
    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Token,

        [ValidateRange('Positive')]
        [int]$ChunkSize = 1MB
    )

    $patterns = @(Get-ByteTokenPattern -Token $Token)
    $measured = $patterns | Measure-Object -Property Length -Maximum
    $overlap = $measured.Maximum - 1
    $buffer = [byte[]]::new($ChunkSize)
    $carry = ''
    $stream = [File]::OpenRead($Path)
    try {
        $read = $stream.Read($buffer, 0, $ChunkSize)
        while ($read -gt 0) {
            $text = $carry + [Encoding]::Latin1.GetString($buffer, 0, $read)
            foreach ($pattern in $patterns) {
                if ($text.Contains($pattern)) {
                    return $true
                }
            }

            $keep = [Math]::Min($text.Length, $overlap)
            $carry = $text.Substring($text.Length - $keep)
            $read = $stream.Read($buffer, 0, $ChunkSize)
        }
    }
    finally {
        $stream.Dispose()
    }

    return $false
}
