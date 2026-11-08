using namespace System.Collections

function Format-FieldValue {
    <#
    .SYNOPSIS
        Returns the text a Write-Field value prints as.
    .DESCRIPTION
        Not exported. A dictionary gives one "key = value" line per entry,
        sorted by the key's text; a list gives one line per item, a list
        inside it included; anything else gives the text it prints as, line
        breaks and all. A dictionary held inside a list or an entry prints
        inline, as {key = value; ...}, so it shows its contents and stays on
        its line.
    .PARAMETER Value
        The value to format.
    .OUTPUTS
        The text, its lines joined by line feeds.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [object]$Value
    )

    if ($Value -is [IDictionary]) {
        return @(Get-DictionaryEntry -Value $Value) -join "`n"
    }

    if (Test-FieldList -Value $Value) {
        return @(Get-FieldItem -Value $Value) -join "`n"
    }

    return "$Value"
}
