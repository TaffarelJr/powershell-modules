using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.Globalization
using namespace System.Xml

function ConvertTo-TestJsonValue {
    <#
    .SYNOPSIS
        Returns a copy of a value in which every number ConvertTo-Json would
        mangle is replaced by a number it can write.
    .DESCRIPTION
        Not exported. ConvertTo-Json writes a BigInteger, Int128, UInt128
        or Half as its properties (often just {}) and a pointer as
        {"value":1}, so two lists of different big integers would print
        alike. A Half becomes a double, a pointer a long or an unsigned
        long, and a BigInteger, Int128 or UInt128 a long or an unsigned long
        when it fits, else its text.

        Only what needs it is copied. A list, dictionary or PSCustomObject
        holding no such number where ConvertTo-Json writes it (see
        Test-JsonConversionNeeded) comes back as itself, so a long list of
        plain numbers costs no copy; one that holds one is copied with its
        contents converted, keys and property names kept exactly. A
        container as deep as ConvertTo-Json writes as text, and anything
        deeper, comes back as itself, so its text is its own and a value
        that contains itself ends.
    .PARAMETER Value
        The value to convert.
    .PARAMETER Depth
        How many containers deep this value sits. Callers leave it out.
    .OUTPUTS
        The converted value, as one object even when it is an array.
    #>
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Value,

        [int]$Depth = 0
    )

    $Value = Get-BaseValue $Value
    $isLeaf = $null -eq $Value -or $Value -is [string] -or $Value -is [XmlNode] -or $Depth -gt 4
    if ($isLeaf) {
        return , $Value
    }

    if ($Value -is [Half]) {
        return [double]$Value
    }

    if ($Value -is [IntPtr]) {
        return $Value.ToInt64()
    }

    if ($Value -is [UIntPtr]) {
        return $Value.ToUInt64()
    }

    if ($Value -is [bigint] -or $Value -is [Int128] -or $Value -is [UInt128]) {
        $text = $Value.ToString([CultureInfo]::InvariantCulture)
        $invariant = [CultureInfo]::InvariantCulture
        $signed = [long]0
        $fitsSigned = [long]::TryParse($text, [NumberStyles]::AllowLeadingSign, $invariant, [ref]$signed)
        if ($fitsSigned) {
            return $signed
        }

        $unsigned = [ulong]0
        $fitsUnsigned = [ulong]::TryParse($text, [NumberStyles]::None, $invariant, [ref]$unsigned)
        if ($fitsUnsigned) {
            return $unsigned
        }

        return $text
    }

    $keepAsIs = $Depth -ge 4 -or -not (Test-JsonConversionNeeded -Value $Value -Depth $Depth)
    if ($keepAsIs) {
        return , $Value
    }

    if ($Value -is [IDictionary]) {
        $copy = [OrderedDictionary]::new()
        foreach ($entry in $Value.GetEnumerator()) {
            $copy.Add($entry.Key, (ConvertTo-TestJsonValue -Value $entry.Value -Depth ($Depth + 1)))
        }

        return , $copy
    }

    if ($Value -is [pscustomobject]) {
        $copy = [OrderedDictionary]::new()
        foreach ($property in $Value.psobject.Properties) {
            $copy.Add($property.Name, (ConvertTo-TestJsonValue -Value $property.Value -Depth ($Depth + 1)))
        }

        return , $copy
    }

    # Only a list is left: anything else needing a conversion was converted
    # above, and Test-JsonConversionNeeded looks into nothing but containers.
    $items = [List[object]]::new()
    foreach ($item in $Value) {
        $plain = $null -eq $item -or $item -is [string] -or
            ($item.GetType().IsPrimitive -and $item -isnot [IntPtr] -and $item -isnot [UIntPtr])
        if ($plain) {
            $items.Add($item)
            continue
        }

        $items.Add((ConvertTo-TestJsonValue -Value $item -Depth ($Depth + 1)))
    }

    return , $items.ToArray()
}
