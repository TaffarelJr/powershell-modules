using namespace System.Collections.Generic
using namespace System.Text.Json

function ConvertFrom-GitHubJsonArray {
    <#
    .SYNOPSIS
        Converts a JSON array element into an array of converted values.
    .DESCRIPTION
        Not exported. An element of an array has no key, so a string in one
        is never read as a date.
    .PARAMETER Element
        The JSON array.
    .PARAMETER Context
        The conversion's context, from New-GitHubJsonContext.
    .OUTPUTS
        An object[], kept whole however many elements it has.
    #>
    param(
        [Parameter(Mandatory)]
        [JsonElement]$Element,

        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    $objectKind = [JsonValueKind]::Object
    $arrayKind = [JsonValueKind]::Array

    $items = [List[object]]::new($Element.GetArrayLength())
    foreach ($item in $Element.EnumerateArray()) {
        $kind = $item.ValueKind
        if ($kind -eq $objectKind) {
            $items.Add((ConvertFrom-GitHubJsonObject -Element $item -Context $Context))
        }
        elseif ($kind -eq $arrayKind) {
            $items.Add((ConvertFrom-GitHubJsonArray -Element $item -Context $Context))
        }
        else {
            $items.Add((ConvertFrom-GitHubJsonScalar -Element $item))
        }
    }

    return , $items.ToArray()
}
