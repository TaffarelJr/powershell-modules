using namespace System.Text

function Get-StrictEncoding {
    <#
    .SYNOPSIS
        Returns a copy of an encoding that throws on bytes or characters it
        cannot map, instead of substituting one.
    .DESCRIPTION
        Not exported. Every built-in encoding object - Encoding.ASCII,
        Encoding.UTF8, Encoding.GetEncoding(1252) - quietly replaces what it
        cannot map with '?' or U+FFFD, and a rewrite makes that loss
        permanent. A copy is made because the built-in objects are read-only.
    .PARAMETER Encoding
        The encoding to copy.
    .PARAMETER WithoutPreamble
        Returns a copy with no byte order mark, for a file that was read
        without one: Encoding.UTF8, Unicode, BigEndianUnicode, and UTF32 all
        carry a mark, and writing the file back with one would add a mark it
        never had.
    .OUTPUTS
        The strict copy.
    #>
    [CmdletBinding()]
    [OutputType('System.Text.Encoding')]
    param(
        [Parameter(Mandatory)]
        [Encoding]$Encoding,

        [switch]$WithoutPreamble
    )

    [Encoding]$strict = $null
    if ($WithoutPreamble) {
        $strict = switch ($Encoding.CodePage) {
            65001 { [UTF8Encoding]::new($false, $true) }
            1200 { [UnicodeEncoding]::new($false, $false, $true) }
            1201 { [UnicodeEncoding]::new($true, $false, $true) }
            12000 { [UTF32Encoding]::new($false, $false, $true) }
            12001 { [UTF32Encoding]::new($true, $false, $true) }
        }
    }

    if ($null -eq $strict) {
        $strict = $Encoding.Clone()
        $strict.EncoderFallback = [EncoderFallback]::ExceptionFallback
        $strict.DecoderFallback = [DecoderFallback]::ExceptionFallback
    }

    return $strict
}
