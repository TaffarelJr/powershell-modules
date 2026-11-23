using namespace System.Collections
using namespace System.Collections.Generic

function Get-DictionaryFieldEntry {
    <#
    .SYNOPSIS
        Returns the entries of a dictionary as objects with a Name and a Value.
    .DESCRIPTION
        Not exported. The name is the key as text. A hashtable keeps no order,
        and its order differs from one process to the next, so its entries come
        back sorted by name; any other dictionary keeps its own order.
    .PARAMETER Dictionary
        The dictionary to read.
    .OUTPUTS
        One object with a Name and a Value for each entry.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [IDictionary]$Dictionary
    )

    $entries = [List[object]]::new()
    foreach ($entry in $Dictionary.GetEnumerator()) {
        $name = "$($entry.Key)"
        $entries.Add([PSCustomObject]@{ Name = $name; Value = $entry.Value })
    }

    if ($Dictionary -is [hashtable]) {
        return $entries | Sort-Object -Property Name
    }

    Write-Output $entries
}
