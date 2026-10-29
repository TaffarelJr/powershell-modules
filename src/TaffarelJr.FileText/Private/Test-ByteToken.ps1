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
        each chunk is searched as Latin-1, which maps every byte to exactly
        one character: searching that text is searching the bytes. Each chunk
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
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Token,

        [ValidateRange('Positive')]
        [int]$ChunkSize = 1MB
    )

    $latin = [Encoding]::Latin1
    $encodings = @(
        [UTF8Encoding]::new($false)
        [UnicodeEncoding]::new($false, $false)
        [UnicodeEncoding]::new($true, $false)
        [UTF32Encoding]::new($false, $false)
        [UTF32Encoding]::new($true, $false)
    )
    $patterns = foreach ($encoding in $encodings) {
        $latin.GetString($encoding.GetBytes($Token))
    }

    $longest = ($patterns | Measure-Object -Property Length -Maximum).Maximum
    $buffer = [byte[]]::new($ChunkSize)
    $carry = ''
    $stream = [File]::OpenRead($Path)
    try {
        $read = $stream.Read($buffer, 0, $ChunkSize)
        while ($read -gt 0) {
            $text = $carry + $latin.GetString($buffer, 0, $read)
            foreach ($pattern in $patterns) {
                if ($text.Contains($pattern)) {
                    return $true
                }
            }

            $keep = [Math]::Min($text.Length, $longest - 1)
            $carry = $text.Substring($text.Length - $keep)
            $read = $stream.Read($buffer, 0, $ChunkSize)
        }
    }
    finally {
        $stream.Dispose()
    }

    return $false
}
