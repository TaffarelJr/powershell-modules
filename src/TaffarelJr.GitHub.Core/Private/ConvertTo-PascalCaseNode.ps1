using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Collections.Specialized

function ConvertTo-PascalCaseNode {
    <#
    .SYNOPSIS
        Returns a copy of an already-parsed value with its property names
        re-cased, recursively.
    .DESCRIPTION
        Not exported. The walk ConvertTo-PascalCaseObject runs: an object
        (a PSCustomObject or a dictionary) is rebuilt with the same rules
        as ConvertFrom-GitHubJson's - cached names, a collision keeping the
        later key's own name, and a case-sensitive dictionary where a
        PSCustomObject cannot hold the names - and a list is rebuilt
        element by element. Anything else is returned as it is.
    .PARAMETER Node
        The value to copy.
    .PARAMETER Context
        The conversion's context, from New-GitHubJsonContext.
    .PARAMETER KeyedByData
        Treats an object's keys as data: kept exactly, in a case-sensitive
        dictionary, and never matched against KeepKeysOf.
    .OUTPUTS
        The copy; an array is kept whole. Nothing for $null.
    #>
    param(
        [AllowNull()]
        [object]$Node,

        [Parameter(Mandatory)]
        [hashtable]$Context,

        [bool]$KeyedByData
    )

    if ($null -eq $Node -or $Node -is [string] -or $Node -is [ValueType]) {
        return $Node
    }

    $isDictionary = $Node -is [IDictionary]
    if (-not $isDictionary -and $Node -is [IList]) {
        $items = [List[object]]::new()
        foreach ($item in $Node) {
            $items.Add((ConvertTo-PascalCaseNode -Node $item -Context $Context))
        }

        return , $items.ToArray()
    }

    if (-not $isDictionary -and $Node.PSObject.BaseObject -isnot [System.Management.Automation.PSCustomObject]) {
        return $Node
    }

    $entries = if ($isDictionary) { $Node.GetEnumerator() } else { $Node.PSObject.Properties }
    $names = $Context.Names
    $kept = $Context.KeepKeysOf
    $reserved = $Context.Reserved

    $exact = $KeyedByData
    $originals = $null
    $members = [ordered]@{}
    if ($KeyedByData) {
        $members = [OrderedDictionary]::new([StringComparer]::Ordinal)
    }

    foreach ($entry in $entries) {
        $name = if ($isDictionary) { [string]$entry.Key } else { $entry.Name }
        $value = $entry.Value

        $target = $name
        if (-not $KeyedByData) {
            $target = $names[$name]
            if ($null -eq $target) {
                $target = Add-GitHubJsonName -Context $Context -Name $name
            }
        }

        $converted = $value
        if ($null -ne $value -and $value -isnot [string] -and $value -isnot [ValueType]) {
            $keyed = -not $KeyedByData -and $kept.ContainsKey($name)
            $converted = ConvertTo-PascalCaseNode -Node $value -Context $Context -KeyedByData $keyed
        }

        if ($exact -or $members.Contains($target) -or $reserved.ContainsKey($target)) {
            if ($null -eq $originals) {
                if ($isDictionary) {
                    $originals = [string[]]@($Node.PSBase.Keys)
                }
                else {
                    $originals = [string[]]@($Node.PSObject.Properties.Name)
                }
            }

            $member = @{
                Members   = [ref]$members
                Name      = $target
                Original  = $name
                Value     = $converted
                Exact     = $exact
                Originals = $originals
                Context   = $Context
            }
            $exact = Add-GitHubObjectMember @member
        }
        else {
            $members[$target] = $converted
        }
    }

    if ($exact) {
        return $members
    }

    return [PSCustomObject]$members
}
