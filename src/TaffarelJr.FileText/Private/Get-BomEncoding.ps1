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
        marks alone cannot tell the two apart. Bytes with no mark
        are UTF-8 without one, which is also what .NET assumes when it
        decodes. Every encoding returned throws on bytes or characters it
        cannot map, rather than substituting one and corrupting the text.
    .PARAMETER Byte
        The start of the file; only the first four bytes are looked at.
    .OUTPUTS
        A PSCustomObject with Encoding and PreambleLength.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]]$Byte
    )

    $count = $Byte.Count
    $encoding = [UTF8Encoding]::new($false, $true)
    $length = 0

    if ($count -ge 3 -and $Byte[0] -eq 0xEF -and $Byte[1] -eq 0xBB -and $Byte[2] -eq 0xBF) {
        $encoding = [UTF8Encoding]::new($true, $true)
        $length = 3
    }
    elseif ($count -ge 4 -and $Byte[0] -eq 0xFF -and $Byte[1] -eq 0xFE -and $Byte[2] -eq 0 -and $Byte[3] -eq 0) {
        $encoding = [UTF32Encoding]::new($false, $true, $true)
        $length = 4
    }
    elseif ($count -ge 4 -and $Byte[0] -eq 0 -and $Byte[1] -eq 0 -and $Byte[2] -eq 0xFE -and $Byte[3] -eq 0xFF) {
        $encoding = [UTF32Encoding]::new($true, $true, $true)
        $length = 4
    }
    elseif ($count -ge 2 -and $Byte[0] -eq 0xFF -and $Byte[1] -eq 0xFE) {
        $encoding = [UnicodeEncoding]::new($false, $true, $true)
        $length = 2
    }
    elseif ($count -ge 2 -and $Byte[0] -eq 0xFE -and $Byte[1] -eq 0xFF) {
        $encoding = [UnicodeEncoding]::new($true, $true, $true)
        $length = 2
    }

    return [PSCustomObject]@{
        Encoding       = $encoding
        PreambleLength = $length
    }
}
