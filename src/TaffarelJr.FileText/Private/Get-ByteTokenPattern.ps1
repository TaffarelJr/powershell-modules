using namespace System.Text

function Get-ByteTokenPattern {
    <#
    .SYNOPSIS
        Returns a token as the bytes it would be in each Unicode encoding,
        each written as a Latin-1 string.
    .DESCRIPTION
        Not exported. Latin-1 maps every byte to exactly one character, so
        searching a file's bytes read as Latin-1 for one of these strings is
        searching the file for the token. The encodings are UTF-16 and UTF-32
        in both byte orders, and UTF-8.
    .PARAMETER Token
        The text to look for.
    .OUTPUTS
        One string for each encoding.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Token
    )

    $encodings = @(
        [UnicodeEncoding]::new($false, $false)
        [UnicodeEncoding]::new($true, $false)
        [UTF32Encoding]::new($false, $false)
        [UTF32Encoding]::new($true, $false)
        [UTF8Encoding]::new($false)
    )
    foreach ($encoding in $encodings) {
        [Encoding]::Latin1.GetString($encoding.GetBytes($Token))
    }
}
