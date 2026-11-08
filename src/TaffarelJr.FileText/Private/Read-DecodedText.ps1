using namespace System.IO
using namespace System.Text

function Read-DecodedText {
    <#
    .SYNOPSIS
        Reads a file once, and decodes it by its byte order mark.
    .DESCRIPTION
        Not exported. Bytes that are not valid in the encoding are not an
        error here: the text comes back decoded loosely, with Problem saying
        what was wrong, so a caller that only has to know whether a token is
        present can still look, and one that is about to rewrite the file can
        refuse instead - a rewrite would turn each such byte into a
        replacement character for good.
    .PARAMETER Path
        The full path of the file, as Resolve-TextFilePath returns it.
    .PARAMETER Encoding
        What to decode a file with no byte order mark as, instead of UTF-8.
        A byte order mark still decides. It is used strictly, and without a
        mark of its own, so the Encoding returned writes the file back with
        the same bytes it was read from.
    .OUTPUTS
        A PSCustomObject with Content, Encoding, and Problem ($null when the
        bytes were all valid).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Encoding]$Encoding
    )

    try {
        $bytes = [File]::ReadAllBytes($Path)
    }
    catch {
        throw "Cannot read '$Path': $($_.Exception.GetBaseException().Message)"
    }

    $bom = Get-BomEncoding -Byte $bytes
    $chosen = if ($bom.PreambleLength -gt 0 -or $null -eq $Encoding) {
        $bom.Encoding
    }
    else {
        Get-StrictEncoding -Encoding $Encoding -WithoutPreamble
    }

    $length = $bytes.Length - $bom.PreambleLength
    $problem = $null
    try {
        $content = $chosen.GetString($bytes, $bom.PreambleLength, $length)
    }
    catch {
        $loose = [Encoding]::GetEncoding($chosen.CodePage)
        $content = $loose.GetString($bytes, $bom.PreambleLength, $length)
        $problem = "'$Path' is not valid $($chosen.WebName) text: " +
        "$($_.Exception.GetBaseException().Message) " +
        'Rewriting it would corrupt it; pass -Encoding if it is in another encoding.'
    }

    return [PSCustomObject]@{
        Content  = $content
        Encoding = $chosen
        Problem  = $problem
    }
}
