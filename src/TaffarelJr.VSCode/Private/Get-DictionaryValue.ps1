using namespace System.Collections

function Get-DictionaryValue {
    <#
    .SYNOPSIS
        Returns the value a dictionary holds under a name, matching the name
        in any casing.
    .DESCRIPTION
        Not exported. A dictionary's own lookup may be case-sensitive, as a
        Dictionary[string, object] is, or typed to keys that are not
        strings, where looking a name up throws. Walking the keys instead
        finds 'path' for Path in either, and skips any key that is not a
        string.
    .PARAMETER Dictionary
        The dictionary to read.
    .PARAMETER Name
        The entry to find.
    .OUTPUTS
        The first matching entry's value, or nothing when there is none.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [IDictionary]$Dictionary,

        [Parameter(Mandatory)]
        [string]$Name
    )

    foreach ($key in $Dictionary.PSBase.Keys) {
        if ($key -is [string] -and $key -eq $Name) {
            return $Dictionary[$key]
        }
    }

    return
}
