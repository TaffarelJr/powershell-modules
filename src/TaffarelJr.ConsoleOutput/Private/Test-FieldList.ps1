using namespace System.Collections

function Test-FieldList {
    <#
    .SYNOPSIS
        Returns whether a value is a list whose items print one by one.
    .DESCRIPTION
        Not exported. Text and dictionaries enumerate too, but are not lists
        here: text prints whole, and a dictionary prints as its entries.
    .PARAMETER Value
        The value to test.
    .OUTPUTS
        True for a list.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [object]$Value
    )

    return $Value -is [IEnumerable] -and
        $Value -isnot [string] -and
        $Value -isnot [IDictionary]
}
