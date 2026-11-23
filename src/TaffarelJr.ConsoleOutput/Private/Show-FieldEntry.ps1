function Show-FieldEntry {
    <#
    .SYNOPSIS
        Prints entries as fields, with their values in one column.
    .DESCRIPTION
        Not exported. Prints each entry with Show-Field. Without a budget the
        column is as wide as the longest name.
    .PARAMETER Entry
        Objects with a Name and a Value property.
    .PARAMETER Budget
        The width of the name column. 0 fits it to the longest name.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Entry,

        [ValidateRange('NonNegative')]
        [int]$Budget
    )

    if ($Entry.Count -eq 0) {
        return
    }

    if ($Budget -eq 0) {
        $Budget =($Entry.Name | Measure-Object -Property Length -Maximum).Maximum
    }

    foreach ($item in $Entry) {
        Show-Field -Name $item.Name -Value $item.Value -Budget $Budget
    }
}
