using namespace System.Collections
using namespace System.Collections.Generic

function ConvertTo-PascalCaseObject {
    <#
    .SYNOPSIS
        Returns a copy of a parsed JSON value with every property name
        re-cased to PascalCase, recursively.
    .DESCRIPTION
        Not exported. gh names its --json fields in camelCase (headRefName,
        isDraft); PowerShell objects name their properties in PascalCase
        (HeadRefName, IsDraft), as every other module here does. One
        generic pass keeps each public function from mapping its fields by
        hand. A value that is not an object or an array - a string, number,
        bool, date, or $null - is returned as-is.
    .PARAMETER InputObject
        The value to re-case, typically ConvertFrom-Json's output.
    .OUTPUTS
        The same shape as the input, with PascalCase property names. An
        array stays an array - the leading comma on that return is what
        keeps a one-element array from unrolling.
    #>
    param(
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject -or $InputObject -is [string]) {
        return $InputObject
    }

    if ($InputObject -is [IList]) {
        $items = [List[object]]::new()
        foreach ($item in $InputObject) {
            $items.Add((ConvertTo-PascalCaseObject -InputObject $item))
        }

        return , $items.ToArray()
    }

    if ($InputObject.PSObject.BaseObject -is [System.Management.Automation.PSCustomObject]) {
        $properties = [ordered]@{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $name = $property.Name.Substring(0, 1).ToUpperInvariant() + $property.Name.Substring(1)
            $properties[$name] = ConvertTo-PascalCaseObject -InputObject $property.Value
        }

        return [PSCustomObject]$properties
    }

    return $InputObject
}
