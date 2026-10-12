using namespace System.Collections.Specialized
using namespace System.Globalization
using namespace System.Text.Json

function ConvertFrom-GitHubJsonObject {
    <#
    .SYNOPSIS
        Converts a JSON object element into a PSCustomObject, or into a
        case-sensitive ordered dictionary when its keys need one.
    .DESCRIPTION
        Not exported. One pass over the object: each key becomes its
        property name through the context's cache, each string, number,
        and literal is converted in place, and only a nested object or
        array costs another call - so a long list stays close to the cost
        of parsing it.

        A string stays a string. It becomes a [datetime] only under a key
        ending in At, _at, or Date, and only when it is an ISO 8601
        timestamp; there a year-0001 value - Go's "no time" - is $null,
        and one .NET cannot hold - February 30, a leap second, a time
        beyond year 9999 once converted to local time - stays its text.
    .PARAMETER Element
        The JSON object.
    .PARAMETER Context
        The conversion's context, from New-GitHubJsonContext.
    .PARAMETER KeyedByData
        Treats the keys as data: kept exactly, in a case-sensitive
        dictionary, never read as dates and never matched against
        KeepKeysOf. What they hold is converted as usual.
    .OUTPUTS
        A PSCustomObject, or an OrderedDictionary with an ordinal comparer.
    #>
    param(
        [Parameter(Mandatory)]
        [JsonElement]$Element,

        [Parameter(Mandatory)]
        [hashtable]$Context,

        [bool]$KeyedByData
    )

    $names = $Context.Names
    $dates = $Context.DateKeys
    $kept = $Context.KeepKeysOf
    $reserved = $Context.Reserved
    $iso = $Context.Iso
    $stringKind = [JsonValueKind]::String
    $objectKind = [JsonValueKind]::Object
    $arrayKind = [JsonValueKind]::Array
    $invariant = [CultureInfo]::InvariantCulture
    $roundtrip = [DateTimeStyles]::RoundtripKind
    $parsed = [datetime]::MinValue

    $exact = $KeyedByData
    $originals = $null
    $members = [ordered]@{}
    if ($KeyedByData) {
        $members = [OrderedDictionary]::new([StringComparer]::Ordinal)
    }

    foreach ($property in $Element.EnumerateObject()) {
        $name = $property.Name
        $value = $property.Value
        $kind = $value.ValueKind

        $target = $name
        if (-not $KeyedByData) {
            $target = $names[$name]
            if ($null -eq $target) {
                $target = Add-GitHubJsonName -Context $Context -Name $name
            }
        }

        if ($kind -eq $stringKind) {
            $converted = $value.GetString()
            if (-not $KeyedByData -and $dates[$name] -and $iso.IsMatch($converted)) {
                # gh writes a time that was never set as Go's zero time, which would read as a real date.
                if ($converted.StartsWith('0001-')) {
                    $converted = $null
                }
                elseif ([datetime]::TryParse($converted, $invariant, $roundtrip, [ref]$parsed)) {
                    $converted = $parsed
                }
            }
        }
        elseif ($kind -eq $objectKind) {
            $keyed = -not $KeyedByData -and $kept.ContainsKey($name)
            $converted = ConvertFrom-GitHubJsonObject -Element $value -Context $Context -KeyedByData $keyed
        }
        elseif ($kind -eq $arrayKind) {
            $converted = ConvertFrom-GitHubJsonArray -Element $value -Context $Context
        }
        else {
            $converted = ConvertFrom-GitHubJsonScalar -Element $value
        }

        if ($exact -or $members.Contains($target) -or $reserved.ContainsKey($target)) {
            if ($null -eq $originals) {
                $originals = [string[]]@(foreach ($each in $Element.EnumerateObject()) { $each.Name })
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
