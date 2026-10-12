using namespace System.Collections

function ConvertTo-GitHubCacheReference {
    <#
    .SYNOPSIS
        Returns the cache id or key gh takes, from either or from a cache
        object.
    .DESCRIPTION
        An object - one of Get-GitHubCache's - is read by its Id, and only
        when it also has a Key, as every cache does: a workflow, a run, or
        anything else with an Id would otherwise name whichever cache
        happens to have that number. A hashtable is read by its Id and Key
        keys, in any case. Text and numbers are the id or key itself,
        spaces included, since a key may hold them.

        A parameter that takes both a value and an object by pipeline must
        be an [object]: as a [string], PowerShell turns a piped object into
        its text ("@{Id=...}") instead of reading its Id.
    .PARAMETER Cache
        A cache id or key, or a cache object.
    .OUTPUTS
        The id or key as text.
    .EXAMPLE
        $reference = ConvertTo-GitHubCacheReference -Cache $cache

        Gives '5000000001' for a cache object whose Id is that.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Cache
    )

    if ($Cache -is [string] -or $Cache -is [ValueType]) {
        $text = "$Cache"
        if ($text -notmatch '\S') {
            throw "'$text' is not a cache: give its id or key, or a cache object."
        }

        return $text
    }

    $values = @{}
    if ($Cache -is [IDictionary]) {
        foreach ($key in $Cache.PSBase.Keys) {
            $values["$key"] = $Cache[$key]
        }
    }
    else {
        foreach ($property in $Cache.PSObject.Properties) {
            $values[$property.Name] = $property.Value
        }
    }

    $id = "$($values['Id'])"
    if ($id -notmatch '\S' -or "$($values['Key'])" -notmatch '\S') {
        throw "A cache object needs an Id and a Key, as Get-GitHubCache gives, and this one lacks one:" +
        " $($Cache.GetType().Name)."
    }

    return $id
}
