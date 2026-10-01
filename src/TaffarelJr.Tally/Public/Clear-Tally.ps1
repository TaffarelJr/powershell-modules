function Clear-Tally {
    <#
    .SYNOPSIS
        Resets one counter, or every counter.
    .DESCRIPTION
        Clearing a name that was never added is a no-op, not an error -
        the module keeps no sense of which names are "valid" to clear.
    .PARAMETER Name
        The counter to remove. Omit it to remove every counter instead.
    .PARAMETER Key
        Clears this namespace instead of the shared, global counters -
        see Add-Tally.
    .EXAMPLE
        Clear-Tally -Name 'passed'
    .EXAMPLE
        Clear-Tally
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [string]$Key
    )

    $tallies = Get-TallyBucket -Key $Key

    if ($PSBoundParameters.ContainsKey('Name')) {
        $tallies.Remove($Name)
        return
    }

    $tallies.Clear()
}
