using namespace System.Collections.Generic

function Get-ListFieldEntry {
    <#
    .SYNOPSIS
        Returns the elements of a list as objects with a Name and a Value.
    .DESCRIPTION
        Not exported. An element is named by its position, counted from 0.
        An element that has a Name or Key property and a Value property,
        such as the entry of a dictionary, keeps its own name and value.
    .PARAMETER Element
        The elements of the list.
    .OUTPUTS
        One object with a Name and a Value for each element.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]]$Element
    )

    $entries = [List[object]]::new()
    $position = 0
    foreach ($item in $Element) {
        $name = "$position"
        $value = $item
        if ($null -ne $item) {
            $properties = $item.PSObject.Properties
            $label = $properties['Name'] ?? $properties['Key']
            if ($null -ne $label -and $null -ne $properties['Value']) {
                $name = "$($label.Value)"
                $value = $properties['Value'].Value
            }
        }

        $entries.Add([PSCustomObject]@{ Name = $name; Value = $value })
        $position++
    }

    Write-Output $entries
}
