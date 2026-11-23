using namespace System.Collections

function Get-FieldEntry {
    <#
    .SYNOPSIS
        Returns what a list, a dictionary or an object holds as entries with a
        Name and a Value.
    .DESCRIPTION
        Not exported. A dictionary gives its entries, named by their keys, a
        list its elements, named by their positions, and a custom object its
        properties.
    .PARAMETER InputObject
        The container to read. See Test-FieldContainer.
    .OUTPUTS
        One object with a Name and a Value for each entry.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [object]$InputObject
    )

    if ($InputObject -is [IDictionary]) {
        return Get-DictionaryFieldEntry -Dictionary $InputObject
    }

    if ($InputObject -is [IEnumerable]) {
        return Get-ListFieldEntry -Element $InputObject
    }

    return $InputObject.PSObject.Properties
}
