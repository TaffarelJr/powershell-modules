using namespace System.Collections.Generic

function Show-FieldList {
    <#
    .SYNOPSIS
        Prints a list, a dictionary or an object as fields, with their values
        lined up.
    .DESCRIPTION
        Prints each element as a field, as Show-Field does, in gray at the
        current indent, with every name padded to the longest so the values
        start in the same column.
        A list is its elements, named by their position from 0.
        A dictionary is its entries, named by their keys; a hashtable keeps no
        order, so its entries are sorted by name, and any other dictionary
        keeps its own order.
        An object is its properties.
        Piped values are the elements of a list, named by position.
        An element with a Name or Key property and a Value property, such as
        the entry of a dictionary, is printed under that name instead.
        Nothing is printed until the input has ended, because the column
        depends on the longest name; if what feeds the pipeline throws,
        nothing is printed at all.
        A value that is itself a list, a dictionary, or an object is printed
        as its name alone, with its own fields one level in, lined up in a
        column of their own. -Depth says how many levels of those are opened;
        a value below that is shown as the text PowerShell makes of it. An
        object's properties are only opened when it is a custom object, as
        Select-Object returns; any other object is text.
        A single value, such as a string, a number or $null, is printed as a
        list of one, at position 0; Show-Field prints it by a name of your
        own.
        If a line was left open, it is ended first.
    .PARAMETER InputObject
        The list, dictionary or object to print, or a single value.
    .PARAMETER Budget
        The width of the name column, as for Show-Field. Without it the
        column is as wide as the longest name. It applies to the top level
        only.
    .PARAMETER Depth
        How many levels of lists, dictionaries, and objects inside the top one
        are opened. 0 opens none, so every value is text. The default is 3,
        which also ends a structure that contains itself.
    .INPUTS
        System.Object. The elements of the list; all of them are printed
        together.
    .OUTPUTS
        None. The lines are written to the host.
    .EXAMPLE
        Show-FieldList ([ordered]@{ Branch = 'main'; 'Remote URL' = 'origin' })

        Prints the two fields with their values in the same column.
    .EXAMPLE
        Show-FieldList ([ordered]@{ Name = 'tool'; Paths = @('src', 'test') })

        Prints "Name: tool", then "Paths:" with its two elements under it.
    .EXAMPLE
        'a', 'b' | Show-FieldList

        Prints "0: a" and "1: b".
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Show-Field
    .LINK
        Get-Indent
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowNull()]
        [object]$InputObject,

        [ValidateRange('Positive')]
        [int]$Budget,

        [ValidateRange('NonNegative')]
        [int]$Depth = 3
    )

    begin {
        $piped = $MyInvocation.ExpectingInput
        $items = [List[object]]::new()
    }

    process {
        if ($piped) {
            $items.Add($InputObject)
            return
        }

        $container = $InputObject
        if (-not (Test-FieldContainer $InputObject)) {
            $container = @($InputObject)
        }

        $entries = @(Get-FieldEntry -InputObject $container)
        Show-FieldEntry -Entry $entries -Budget $Budget -Depth $Depth
    }

    end {
        if ($piped) {
            $entries = @(Get-ListFieldEntry -Element $items)
            Show-FieldEntry -Entry $entries -Budget $Budget -Depth $Depth
        }
    }
}
