using namespace System.Text

function Get-BomEncoding {
    <#
    .SYNOPSIS
        Reads the byte order mark at the start of some bytes, and returns the
        encoding it names and how many bytes it takes up.
    .DESCRIPTION
        Not exported. UTF-32 is checked before UTF-16, since a UTF-32 little
        endian mark begins with the whole of a UTF-16 one, so UTF-16 little
        endian text whose first character is U+0000 is taken for UTF-32 - the
        marks alone cannot tell the two apart. Bytes with no mark are UTF-8
        without one, which is also what .NET assumes when it decodes. Every
        encoding returned throws on bytes or characters it cannot map, rather
        than substituting one and corrupting the text.
    .PARAMETER Byte
        The start of the file; only the first four bytes are looked at.
    .OUTPUTS
        A PSCustomObject with Encoding and PreambleLength.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]]$Byte
    )

    $head = [BitConverter]::ToString($Byte, 0, [Math]::Min(4, $Byte.Count))
    $encoding = [UTF8Encoding]::new($false, $true)
    $length = 0

    if ($head.StartsWith('EF-BB-BF')) {
        $encoding = [UTF8Encoding]::new($true, $true)
        $length = 3
    }
    elseif ($head.StartsWith('FF-FE-00-00')) {
        $encoding = [UTF32Encoding]::new($false, $true, $true)
        $length = 4
    }
    elseif ($head.StartsWith('00-00-FE-FF')) {
        $encoding = [UTF32Encoding]::new($true, $true, $true)
        $length = 4
    }
    elseif ($head.StartsWith('FF-FE')) {
        $encoding = [UnicodeEncoding]::new($false, $true, $true)
        $length = 2
    }
    elseif ($head.StartsWith('FE-FF')) {
        $encoding = [UnicodeEncoding]::new($true, $true, $true)
        $length = 2
    }

    return [PSCustomObject]@{
        Encoding       = $encoding
        PreambleLength = $length
    }
}
