using namespace System.Collections.Generic

function Get-TallyKey {
    <#
    .SYNOPSIS
        Returns the keys of the adds that carry every given tag.
    .DESCRIPTION
        Not exported. An add carries a tag when the tag is one of the tags it
        was made under, without regard to case. With no tags every key matches.
        The caller holds the lock on the state.
    .PARAMETER State
        The process-wide record, from Get-TallyState.
    .PARAMETER Tag
        The tags an add must carry, or $null for none.
    .OUTPUTS
        The matching keys, as strings.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [Dictionary[string, long]]$State,

        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Tag
    )

    $asked = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Tag) {
        $null = $asked.Add($item)
    }

    $found = [List[string]]::new()
    foreach ($key in $State.PSBase.Keys) {
        $carried = [HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $parts = $key.Split("`n", [StringSplitOptions]::RemoveEmptyEntries)
        foreach ($item in $parts) {
            $null = $carried.Add($item)
        }

        if ($carried.IsSupersetOf($asked)) {
            $found.Add($key)
        }
    }

    Write-Output $found
}
