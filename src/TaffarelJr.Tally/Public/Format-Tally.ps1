function Format-Tally {
    <#
    .SYNOPSIS
        Renders counters as one joined string - "3 passed - 1 failed" -
        for a caller to print, log, or send anywhere else.
    .DESCRIPTION
        Returns a string; it never writes to the host itself.
        A name in -Name that was never added still appears,
        at zero, rather than being skipped -
        useful for a summary line that always shows every category
        even when one of them never fired.
    .PARAMETER Name
        Which counters to include, and in what order.
        Omit it to include every counter,
        in the order each name was first added.
    .PARAMETER Separator
        Joins each "<Count> <Name>" part together. Defaults to ' - '.
    .EXAMPLE
        Format-Tally -Name @('passed', 'failed', 'crashed')
    #>
    param(
        [Parameter(Position = 0)]
        [string[]]$Name,

        [string]$Separator = ' - '
    )

    $names = if ($PSBoundParameters.ContainsKey('Name')) {
        $Name
    }
    else {
        @($script:Tallies.Keys)
    }

    $parts = foreach ($key in $names) {
        $count = if ($script:Tallies.Contains($key)) {
            $script:Tallies[$key]
        }
        else {
            0
        }

        "$count $key"
    }

    return ($parts -join $Separator)
}
