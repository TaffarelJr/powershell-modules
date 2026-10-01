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
    .EXAMPLE
        Get-Tally -Name 'passed'
    .EXAMPLE
        Get-Tally
    #>
    param(
        [Parameter(Position = 0)]
        [string]$Name
    )

    if ($PSBoundParameters.ContainsKey('Name')) {
        if ($script:Tallies.Contains($Name)) {
            return $script:Tallies[$Name]
        }

        return 0
    }

    return , @(foreach ($key in $script:Tallies.Keys) {
            [pscustomobject]@{
                Name  = $key
                Count = $script:Tallies[$key]
            }
        })
}
