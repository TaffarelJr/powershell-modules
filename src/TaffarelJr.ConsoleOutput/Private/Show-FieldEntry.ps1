function Show-FieldEntry {
    <#
    .SYNOPSIS
        Prints entries as fields, with their values in one column.
    .DESCRIPTION
        Not exported. Prints each entry with Show-Field. Without a budget the
        column is as wide as the longest name of an entry printed with its
        value.
        While there is depth left, an entry whose value is a list, a
        dictionary or an object is printed as its name alone, followed by the
        entries of that value one level in, which fit a column of their own.
        Without depth left, or for any other value, the entry is printed with
        its value as text.
    .PARAMETER Entry
        Objects with a Name and a Value property.
    .PARAMETER Budget
        The width of the name column. 0 fits it to the longest name.
    .PARAMETER Depth
        How many levels of nested values are opened. 0 prints none of them.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Entry,

        [ValidateRange('NonNegative')]
        [int]$Budget,

        [ValidateRange('NonNegative')]
        [int]$Depth
    )

    if ($Entry.Count -eq 0) {
        return
    }

    $opens = {
        param($Item)
        $Depth -gt 0 -and (Test-FieldContainer $Item.Value)
    }

    if ($Budget -eq 0) {
        $leaf = @($Entry | Where-Object { -not (& $opens $_) })
        if ($leaf.Count -gt 0) {
            $Budget = ($leaf.Name | Measure-Object -Property Length -Maximum).Maximum
        }
    }

    foreach ($item in $Entry) {
        if (-not (& $opens $item)) {
            Show-Field -Name $item.Name -Value $item.Value -Budget $Budget
            continue
        }

        Show-Field -Name $item.Name -Value $null
        Push-Indent
        try {
            $children = @(Get-FieldEntry -InputObject $item.Value)
            Show-FieldEntry -Entry $children -Depth ($Depth - 1)
        }
        finally {
            Pop-Indent
        }
    }
}
