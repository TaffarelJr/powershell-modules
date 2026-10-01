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
    param(
        [Parameter(Mandatory)]
        [Encoding]$Encoding,

        [switch]$WithoutPreamble
    )

    if ($WithoutPreamble) {
        switch ($Encoding.CodePage) {
            65001 {
                return [UTF8Encoding]::new($false, $true)
            }
            1200 {
                return [UnicodeEncoding]::new($false, $false, $true)
            }
            1201 {
                return [UnicodeEncoding]::new($true, $false, $true)
            }
            12000 {
                return [UTF32Encoding]::new($false, $false, $true)
            }
            12001 {
                return [UTF32Encoding]::new($true, $false, $true)
            }
        }
    }

    $strict = $Encoding.Clone()
    $strict.EncoderFallback = [EncoderFallback]::ExceptionFallback
    $strict.DecoderFallback = [DecoderFallback]::ExceptionFallback
    return $strict
}
