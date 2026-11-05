using namespace System.Collections.Specialized

function Add-GitHubObjectMember {
    <#
    .SYNOPSIS
        Adds a member to an object being built when its name is taken or
        cannot be a PowerShell property, and says whether the object is
        now a dictionary.
    .DESCRIPTION
        Not exported. The slow path of building a converted object: the
        common case - a free, ordinary name - is added by the caller
        directly.

        A name another key already came out as goes back to the key's own
        name, so the later value is kept under its original name. A
        PSCustomObject's property names are case-insensitive and a few are
        reserved (PSObject, PSBase, PSAdapted, PSExtended, PSTypeNames, and
        an empty name), so when even the original name will not fit, the
        object switches to a case-sensitive ordered dictionary holding what
        it had so far, and keeps every key from then on. When the original
        name is itself what an earlier key came out as - foo, then Foo -
        that earlier member goes back to its own key's name, so both are
        kept. A key the JSON gives twice in one object throws instead of
        losing a value; every repeat reaches this slow path, since its name
        is always taken by then.
    .PARAMETER Members
        The members so far, one per key before this one and in the same
        order: an [ordered] dictionary while the object can still be a
        PSCustomObject, the case-sensitive one after. Replaced when the
        object switches, or when a member is renamed.
    .PARAMETER Name
        The name the key came out as.
    .PARAMETER Original
        The key as the JSON has it.
    .PARAMETER Value
        The converted value.
    .PARAMETER Exact
        Whether the object is already a case-sensitive dictionary.
    .PARAMETER Originals
        Every key of the object as the JSON has it, in order.
    .PARAMETER Context
        The conversion's context, from New-GitHubJsonContext.
    .OUTPUTS
        $true when the object is now a case-sensitive dictionary.
    #>
    param(
        [Parameter(Mandatory)]
        [ref]$Members,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Original,

        [AllowNull()]
        [object]$Value,

        [bool]$Exact,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Originals,

        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    $dictionary = $Members.Value
    if ([array]::IndexOf($Originals, $Original) -lt $dictionary.PSBase.Count) {
        $shown = Hide-UrlCredential -Text $Original
        throw "A JSON object gives the key '$shown' twice, and one of its values would be lost."
    }

    if ($dictionary.Contains($Name)) {
        $Name = $Original
    }

    $taken = $dictionary.Contains($Name)
    if (-not $taken -and ($Exact -or -not $Context.Reserved.ContainsKey($Name))) {
        $dictionary[$Name] = $Value
        return $Exact
    }

    # Only a repeated key could make a renamed holder clash again, and that threw above.
    $keys = [string[]]@($dictionary.PSBase.Keys)
    $holder = [array]::IndexOf($keys, $Name)
    if ($holder -ge 0) {
        $keys[$holder] = $Originals[$holder]
    }

    $copy = [OrderedDictionary]::new([StringComparer]::Ordinal)
    for ($index = 0; $index -lt $keys.Count; $index++) {
        $copy[$keys[$index]] = $dictionary[$index]
    }

    $copy[$Name] = $Value
    $Members.Value = $copy
    return $true
}
