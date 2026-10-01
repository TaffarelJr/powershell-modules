function Resolve-TallyName {
    <#
    .SYNOPSIS
        Returns the counter name a value stands for, and refuses one no
        counter can have.
    .DESCRIPTION
        Not exported. A string is the name itself, and a number, a boolean,
        a character or an enum value is named by its text. Any other value
        is named by its Name property, so what Get-Tally, Read-Tally or
        Group-Object write can be piped back in, and so can a dictionary
        entry, named by its key. A value with no Name property - a struct
        such as a date included - is refused rather than named by its own
        text, which would count it under a name like "@{Extension=.txt}"
        that nobody asked for.

        A name must be one line, with no leading or trailing whitespace,
        since Format-Tally writes it into a line Read-Tally must split back
        apart. Unicode line and paragraph separators, next-line, vertical
        tab and form feed all break a line too.
    .PARAMETER InputObject
        A name, or an object whose Name property holds one.
    .OUTPUTS
        The name, as a string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$InputObject
    )

    $name = $InputObject
    $isSimple = $null -eq $InputObject -or
        $InputObject -is [string] -or
        $InputObject -is [decimal] -or
        $InputObject -is [enum] -or
        $InputObject.GetType().IsPrimitive
    if (-not $isSimple) {
        $property = $InputObject.PSObject.Properties['Name']
        if ($null -eq $property) {
            $type = [Microsoft.PowerShell.ToStringCodeMethods]::Type($InputObject.GetType())
            throw "Cannot read a tally name from a [$type]: pass the name itself, " +
                'or an object with a Name property (for example, pipe it through ForEach-Object Extension first).'
        }

        $name = $property.Value
    }

    $text = [string]$name
    $pattern = '^\S(?:[^\r\n\v\f\u0085\u2028\u2029]*\S)?$'
    if (-not [regex]::IsMatch($text, $pattern)) {
        throw "'$text' is not a valid tally name: a name must be one line, with no leading or trailing whitespace."
    }

    return $text
}
