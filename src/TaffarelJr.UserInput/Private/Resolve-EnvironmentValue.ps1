function Resolve-EnvironmentValue {
    <#
    .SYNOPSIS
        Returns the text an environment variable's value stands for.
    .DESCRIPTION
        Not exported. A string is the value itself, $null is an empty one, and
        a number, a boolean, a character or an enum value is its text. Any
        other value is read from its Value property, so an object that
        carries a Name and a Value can be piped in whole. A value with no
        Value property, a date or a hashtable included, is refused rather
        than written as its own text, which would save something like
        "@{Name=PATH}" that nobody asked for.
    .PARAMETER InputObject
        The value, or an object whose Value property holds it.
    .OUTPUTS
        The value, as a string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$InputObject
    )

    $isSimple = $null -eq $InputObject -or
        $InputObject -is [string] -or
        $InputObject -is [decimal] -or
        $InputObject -is [enum] -or
        $InputObject.GetType().IsPrimitive
    if ($isSimple) {
        return "$InputObject"
    }

    $property = $InputObject.PSObject.Properties['Value']
    if ($null -eq $property) {
        throw "Cannot read an environment variable's value from a [$($InputObject.GetType().Name)]: " +
            'pass the value itself, or an object with a Value property.'
    }

    return "$($property.Value)"
}
