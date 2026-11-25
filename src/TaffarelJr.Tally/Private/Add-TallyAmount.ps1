using namespace System.Collections.Generic
using namespace System.Threading

function Add-TallyAmount {
    <#
    .SYNOPSIS
        Adds each increment to its counter, all or none.
    .DESCRIPTION
        Not exported. Under one lock on the state, works out every counter's
        new count first and then stores them, so an increment that would take
        a count past what a [long] holds changes no counter. Increments that
        name the same counter, without regard to case, add up before they are
        stored.
    .PARAMETER Increment
        Objects with a Name, the counter, and a Value, the [long] to add.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Increment
    )

    $state = Get-TallyState
    [Monitor]::Enter($state)
    try {
        $comparer = [StringComparer]::OrdinalIgnoreCase
        $planned = [Dictionary[string, long]]::new($comparer)
        foreach ($item in $Increment) {
            $current = [long]0
            if (-not $planned.TryGetValue($item.Name, [ref]$current)) {
                $null = $state.TryGetValue($item.Name, [ref]$current)
            }

            $planned[$item.Name] = [long]([decimal]$current + $item.Value)
        }

        foreach ($entry in $planned.GetEnumerator()) {
            $state[$entry.Key] = $entry.Value
        }
    }
    finally {
        [Monitor]::Exit($state)
    }
}
