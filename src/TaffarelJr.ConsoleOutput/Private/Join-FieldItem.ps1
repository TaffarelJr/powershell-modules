using namespace System.Collections

function Join-FieldItem {
    <#
    .SYNOPSIS
        Returns a value held inside a list or a dictionary entry as one piece
        of text, so it stays on its line.
    .DESCRIPTION
        Not exported. A list becomes its items joined with a comma and a space;
        a dictionary becomes its entries inside braces, joined with a
        semicolon and a space ({a = 1; b = 2}); anything else gives the text
        it prints as.
    .PARAMETER Value
        The value.
    .OUTPUTS
        The text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [object]$Value
    )

    if ($Value -is [IDictionary]) {
        return "{$(@(Get-DictionaryEntry -Value $Value) -join '; ')}"
    }

    if (Test-FieldList -Value $Value) {
        return @(Get-FieldItem -Value $Value) -join ', '
    }

    return "$Value"
}
