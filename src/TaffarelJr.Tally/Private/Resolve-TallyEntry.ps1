function Resolve-TallyEntry {
    <#
    .SYNOPSIS
        Returns the name and the whole-number count one entry stands for, and
        refuses an entry that is neither.
    .DESCRIPTION
        Not exported. An entry is anything with a Name or a Key and a Value or
        a Count: the entry of a dictionary, a pair such as Get-Tally returns,
        or what Group-Object writes. The name must be one a tag can be, and
        the count a whole number: an integer type that fits a [long]. A
        fraction, a number written as text, a double and a number too big for
        a [long] are refused, because a cast would round or wrap them without
        a word.
    .PARAMETER InputObject
        The entry.
    .OUTPUTS
        An object with the Name, a string, and the Value, a [long].
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object]$InputObject
    )

    $label = $null
    $amount = $null
    if ($null -ne $InputObject) {
        $properties = $InputObject.PSObject.Properties
        $label = $properties['Name'] ?? $properties['Key']
        $amount = $properties['Value'] ?? $properties['Count']
    }

    if ($null -eq $label -or $null -eq $amount) {
        throw 'A tally entry needs a name and a count, as a pair does.'
    }

    $name = "$($label.Value)"
    if ($name -notmatch $script:TagPattern) {
        throw "The name '$name' is not one a tag can have."
    }

    $value = $amount.Value
    if ($null -ne $value) {
        $value = $value.PSObject.BaseObject
    }

    $whole = [Type[]]@(
        [sbyte], [byte], [int16], [uint16], [int], [uint32], [long])
    if ($null -eq $value -or $value.GetType() -notin $whole) {
        throw "The count of '$name' is not a whole number."
    }

    return [PSCustomObject]@{ Name = $name; Value = [long]$value }
}
