using namespace System.Collections.Generic

function ConvertTo-TallyKey {
    <#
    .SYNOPSIS
        Returns the key one set of tags is kept under.
    .DESCRIPTION
        Not exported. The tags are a set: order, case and repeats do not matter,
        so they are sorted and de-duplicated without regard to case, and joined
        with a line break, which a tag cannot hold. No tags give an empty key.
    .PARAMETER Tag
        The tags of one add, or $null for none.
    .OUTPUTS
        The key, as a string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Tag
    )

    $tags = [SortedSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Tag) {
        $null = $tags.Add($item)
    }

    return $tags -join "`n"
}
