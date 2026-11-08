using namespace System.Collections

function Get-FieldItem {
    <#
    .SYNOPSIS
        Returns every item of a list as text, with any list inside it
        flattened into the same sequence.
    .DESCRIPTION
        Not exported. A dictionary inside the list is one item, printed inline
        by Join-FieldItem, not a list to flatten.
    .PARAMETER Value
        The list.
    .OUTPUTS
        The items, one at a time.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [IEnumerable]$Value
    )

    foreach ($item in $Value) {
        if (Test-FieldList -Value $item) {
            Get-FieldItem -Value $item
        }
        else {
            Join-FieldItem -Value $item
        }
    }
}
