using namespace System.IO
using namespace System.Text

function Read-GitHubGistFile {
    <#
    .SYNOPSIS
        Returns the exact text of a local file that is to become a gist
        file.
    .DESCRIPTION
        The file must be UTF-8 text that is not empty or blank, and it is
        judged in this order: UTF-16 or UTF-32 with a byte-order mark, and
        UTF-16 without one - an even-length file whose NULs fall mostly on
        one side of each byte pair, at least one pair in four, and that
        reads as UTF-16 text with no control character - is not UTF-8;
        then bytes that are not valid UTF-8 are text in another encoding,
        or binary data when they hold a control byte text never holds (as
        Test-GitHubGistBinary has it), as does UTF-8 that holds one. Each
        throws, as GitHub would hold none of them faithfully. Nothing is
        added or taken away - not a newline - except a UTF-8 byte-order
        mark at the start, which is dropped: a gist file has none, and a
        script saved with one by Windows PowerShell would no longer start
        with its #! line.
    .PARAMETER Path
        The file's full path.
    .PARAMETER Source
        How a message names the file: the value the caller typed, quoted,
        with the parameter it came from where that helps (-AddFile 'x'). It
        is shown as it is, so a caller hides any URL credential in it first.
    .OUTPUTS
        The file's text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Source
    )

    $notUtf8 = "$Source is not UTF-8 text, so it would reach GitHub garbled; save it as UTF-8 first."
    $bytes = [File]::ReadAllBytes($Path)
    $start = [Convert]::ToHexString($bytes, 0, [Math]::Min(4, $bytes.Length))
    if ($start -match '^(FFFE|FEFF|0000FEFF)') {
        throw $notUtf8
    }

    # Without a byte-order mark, UTF-16 is told by its NULs - the high half
    # of each ASCII character, so mostly on one side of each byte pair - and
    # by reading as UTF-16 text that holds no control character. Counted on
    # the start of the file, so a large binary one is not walked byte by byte.
    if ($bytes.Length -ge 2 -and $bytes.Length % 2 -eq 0 -and [Array]::IndexOf($bytes, [byte]0) -ge 0) {
        $sample = [Math]::Min($bytes.Length, 8192)
        $even = 0
        $odd = 0
        for ($i = 0; $i -lt $sample; $i += 2) {
            if ($bytes[$i] -eq 0) {
                $even++
            }

            if ($bytes[$i + 1] -eq 0) {
                $odd++
            }
        }

        if ($even -ne $odd -and [Math]::Max($even, $odd) * 8 -ge $sample) {
            $utf16 = [UnicodeEncoding]::new($even -gt $odd, $false, $true)
            $decoded = $null
            try {
                $decoded = $utf16.GetString($bytes)
            }
            catch [DecoderFallbackException] {
                Write-Debug "Not UTF-16 either: $($_.Exception.Message)"
            }

            if ($null -ne $decoded -and -not (Test-GitHubGistBinary -Text $decoded)) {
                throw $notUtf8
            }
        }
    }

    $offset = 0
    if ($start.StartsWith('EFBBBF', [StringComparison]::Ordinal)) {
        $offset = 3
    }

    $strict = [UTF8Encoding]::new($false, $true)
    try {
        $text = $strict.GetString($bytes, $offset, $bytes.Length - $offset)
    }
    catch [DecoderFallbackException] {
        # An image or an archive rarely decodes as UTF-8, so it is told as binary and not as another encoding;
        # a control character is one byte in UTF-8, so the raw bytes show it.
        if (Test-GitHubGistBinary -Text ([Encoding]::Latin1.GetString($bytes))) {
            throw "$Source holds binary data, and a gist holds text only."
        }

        throw $notUtf8
    }

    Assert-GitHubGistText -Text $text -Source $Source
    return $text
}
