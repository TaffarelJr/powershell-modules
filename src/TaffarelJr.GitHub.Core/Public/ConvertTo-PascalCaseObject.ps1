using namespace System.Collections
using namespace System.Collections.Generic

function ConvertTo-PascalCaseObject {
    <#
    .SYNOPSIS
        Returns a copy of a parsed JSON value with every property name
        re-cased to PascalCase, recursively.
    .DESCRIPTION
        gh's own --json output names fields in camelCase
        (headRefName, isDraft); a raw REST response names them in
        snake_case instead (ref_name, created_at). PowerShell objects
        name their properties in PascalCase (HeadRefName, CreatedAt), as
        every other module here does - so each underscore-separated
        segment is capitalized on its own before being joined back
        together, which leaves a plain camelCase name's single segment
        exactly as a bare "uppercase the first letter" pass always did.
        One generic pass keeps each public function from mapping its
        fields by hand. A value that is not an object or an array - a
        string, number, bool, date, or $null - is returned as-is.
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
            $segments = $property.Name -split '_' | Where-Object { $_ }
            $name = ($segments | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join ''
            $properties[$name] = ConvertTo-PascalCaseObject -InputObject $property.Value
        }

        return [PSCustomObject]$properties
    }

    return $InputObject
}
