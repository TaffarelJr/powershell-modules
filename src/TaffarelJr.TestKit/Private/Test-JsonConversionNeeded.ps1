using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Xml

function Test-JsonConversionNeeded {
    <#
    .SYNOPSIS
        Reports whether a value holds a number ConvertTo-Json would mangle,
        anywhere ConvertTo-Json writes it.
    .DESCRIPTION
        Not exported. The numbers are BigInteger, Int128, UInt128, Half,
        IntPtr and UIntPtr. A value sits at depth 0, the values in it at
        depth 1, and so on: such a number counts down to depth 4, and the
        contents of a container down to depth 3 are looked through, which is
        as deep as ConvertTo-TestJsonValue copies. The walk keeps its own
        list of containers left to look through rather than calling itself,
        and checks every other value where it finds it, so a long list of
        plain numbers costs one cheap check per element.
    .PARAMETER Value
        The value to look through.
    .PARAMETER Depth
        The depth the value itself sits at.
    #>
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Value,

        [int]$Depth = 0
    )

    $mangled = [type[]]@([bigint], [Int128], [UInt128], [Half], [IntPtr], [UIntPtr])
    $pending = [Stack[Tuple[object, int]]]::new()
    $pending.Push([Tuple[object, int]]::new($Value, $Depth))
    while ($pending.Count -gt 0) {
        $entry = $pending.Pop()
        $item = $entry.Item1
        # Handing a value to the .NET tuple drops any PSObject wrapper but a
        # PSCustomObject's own.
        $isObject = $item -is [psobject] -and
            $item.psobject.BaseObject -is [System.Management.Automation.PSCustomObject]
        if ($null -eq $item) {
            continue
        }

        if ($item.GetType() -in $mangled) {
            return $true
        }

        $isLeaf = $item -is [string] -or $item -is [XmlNode] -or $entry.Item2 -ge 4
        if ($isLeaf) {
            continue
        }

        $children = $null
        if ($item -is [IDictionary]) {
            $children = $item.PSBase.Values
        }
        elseif ($isObject) {
            $children = [List[object]]::new()
            foreach ($property in $item.psobject.Properties) {
                $children.Add($property.Value)
            }
        }
        elseif ($item -is [IEnumerable]) {
            $children = $item
        }

        $childDepth = $entry.Item2 + 1
        foreach ($child in $children) {
            if ($null -eq $child -or $child -is [string] -or $child -is [ValueType]) {
                if ($null -ne $child -and $child.GetType() -in $mangled) {
                    return $true
                }

                continue
            }

            $pending.Push([Tuple[object, int]]::new($child, $childDepth))
        }
    }

    return $false
}
