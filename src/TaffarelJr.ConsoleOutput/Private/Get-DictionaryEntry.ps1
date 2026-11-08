using namespace System.Collections

function Get-DictionaryEntry {
    <#
    .SYNOPSIS
        Returns a dictionary's entries as "key = value" text, sorted by the
        key's text.
    .DESCRIPTION
        Not exported. The one place a dictionary is turned into text, for a
        field's own value and for one held inside a list or an entry. An entry
        whose value is a list or a dictionary prints it inline, through
        Join-FieldItem.
    .PARAMETER Value
        The dictionary.
    .OUTPUTS
        The entries, one at a time.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [IDictionary]$Value
    )

    # Enumerate the entries instead of indexing by key: an ordered dictionary
    # reads an integer index as a position, not a key.
    $pairs = @($Value.GetEnumerator())
    if ($pairs.Count -eq 0) {
        return
    }

    $keys = [string[]]@($pairs.ForEach({ "$($_.Key)" }))
    $entries = [string[]]@($pairs.ForEach({ "$($_.Key) = $(Join-FieldItem -Value $_.Value)" }))
    [Array]::Sort($keys, $entries, [StringComparer]::Ordinal)
    foreach ($entry in $entries) {
        $entry
    }
}
