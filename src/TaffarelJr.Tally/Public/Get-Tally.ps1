function Get-Tally {
    <#
    .SYNOPSIS
        Returns one counter's running count, or every counter, by name.
    .DESCRIPTION
        A name that was never passed to Add-Tally
        returns zero rather than an error -
        a caller should not have to pre-declare its categories.
    .PARAMETER Name
        The counter to read.
        Omit it to get every counter instead,
        as an array of Name/Count objects,
        in the order each name was first added.
    .PARAMETER Key
        Reads from this namespace instead of the shared, global counters -
        see Add-Tally.
    .EXAMPLE
        Get-Tally -Name 'passed'
    .EXAMPLE
        Get-Tally
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [string]$Key
    )

    $tallies = Get-TallyBucket -Key $Key

    if ($PSBoundParameters.ContainsKey('Name')) {
        if ($tallies.Contains($Name)) {
            return $tallies[$Name]
        }

        return 0
    }

    return , @(foreach ($k in $tallies.Keys) {
            [PSCustomObject]@{
                Name  = $k
                Count = $tallies[$k]
            }
        })
}
