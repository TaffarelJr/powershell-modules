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
    .PARAMETER Key
        Renders this namespace instead of the shared, global counters -
        see Add-Tally.
    .EXAMPLE
        Format-Tally -Name @('passed', 'failed', 'crashed')
    #>
    param(
        [Parameter(Position = 0)]
        [string[]]$Name,

        [string]$Separator = ' - ',

        [string]$Key
    )

    $tallies = Get-TallyBucket -Key $Key

    $names = if ($PSBoundParameters.ContainsKey('Name')) {
        $Name
    }
    else {
        @($tallies.Keys)
    }

    $parts = foreach ($entryName in $names) {
        $count = if ($tallies.Contains($entryName)) {
            $tallies[$entryName]
        }
        else {
            0
        }

        "$count $entryName"
    }

    return ($parts -join $Separator)
}
