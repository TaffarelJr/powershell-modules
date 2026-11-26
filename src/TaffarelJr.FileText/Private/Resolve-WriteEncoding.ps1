using namespace System.Text

function Resolve-WriteEncoding {
    <#
    .SYNOPSIS
        Returns the encoding a write uses.
    .DESCRIPTION
        Not exported. The encoding the caller gave, if any. Otherwise the one
        the reference file is written in, read from its byte order mark. With
        neither, UTF-8 without a mark. A reference with no mark that is not
        valid UTF-8, Windows-1252 say, has no encoding to read off it, so it
        throws rather than silently turning the file into UTF-8. Every
        encoding returned throws on text it cannot hold.
    .PARAMETER Reference
        The full path of the file to match, as Resolve-WriteReference returns
        it.
    .PARAMETER Encoding
        The encoding the caller asked for.
    .OUTPUTS
        The encoding to write with.
    #>
    [CmdletBinding()]
    [OutputType('System.Text.Encoding')]
    param(
        [string]$Reference,

        [Encoding]$Encoding
    )

    [Encoding]$chosen = [UTF8Encoding]::new($false, $true)
    if ($null -ne $Encoding) {
        $chosen = Get-StrictEncoding -Encoding $Encoding
    }
    elseif ($Reference) {
        $decoded = Read-DecodedText -Path $Reference
        if ($decoded.Problem -and $decoded.Encoding.GetPreamble().Length -eq 0) {
            throw ("Cannot tell what encoding '$Reference' is in:" +
                ' it has no byte order mark and is not valid UTF-8.' +
                ' Pass -Encoding to say which encoding to write.')
        }

        $chosen = $decoded.Encoding
    }

    return $chosen
}
