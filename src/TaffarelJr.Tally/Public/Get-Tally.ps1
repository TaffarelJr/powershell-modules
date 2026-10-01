using namespace System.Collections.Generic
using namespace System.Threading

function Get-Tally {
    <#
    .SYNOPSIS
        Returns one counter's running count, or every counter, by name.
    .DESCRIPTION
        A name that was never passed to Add-Tally
        returns zero rather than an error -
        a caller should not have to pre-declare its categories.
        A name no counter could have, such as an empty one, is refused.
        What comes back is a copy: changing it changes nothing in the tally.
    .PARAMETER Name
        The counter to read: a name, or an object whose Name property holds
        one. Names can be piped in.
        Omit it to get every counter instead,
        as Name/Count objects,
        in the order each name was first added.
    .PARAMETER Key
        Reads from this namespace instead of the shared, global counters -
        see Add-Tally. A $null, empty or blank key is refused rather than
        taken to mean the global counters.
    .INPUTS
        System.Object. A name, or an object with a Name property.
    .OUTPUTS
        System.Int64. With -Name, the count. Without it, one
        System.Management.Automation.PSCustomObject per counter, with Name
        and Count (a [long]) properties, so wrap the call in @() to collect
        them as an array.
    .EXAMPLE
        Get-Tally -Name 'passed'

        Returns how many times passed was added, or zero if it never was.
    .EXAMPLE
        Get-Tally

        Returns a Name/Count object for every counter, in the order each was
        first added.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/README.md
    .LINK
        Add-Tally
    #>
    [CmdletBinding()]
    [OutputType([long])]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object]$Name,

        [ValidatePattern(
            '\S',
            ErrorMessage = 'A tally key must hold a non-blank character; omit -Key for the global counters.'
        )]
        [string]$Key
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            $state = Get-TallyState
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            $byName = $PSBoundParameters.ContainsKey('Name')
            $resolved = $null
            if ($byName) {
                $resolved = Resolve-TallyName -InputObject $Name
            }

            # Everything is read under the lock, but nothing is written to the
            # pipeline until it is released: a downstream command that blocks on
            # another runspace, which in turn needs this lock, would deadlock.
            $count = [long]0
            $copies = [List[object]]::new()
            [Monitor]::Enter($state)
            try {
                $tallies = Get-TallyBucket -Key $Key
                if ($byName) {
                    if ($null -ne $tallies -and $tallies.Contains($resolved)) {
                        $count = $tallies[$resolved].Count
                    }
                }
                elseif ($null -ne $tallies) {
                    # PSBase: a counter named Values would otherwise be read
                    # in place of every counter.
                    foreach ($record in $tallies.PSBase.Values) {
                        $copies.Add([PSCustomObject]@{
                                Name  = $record.Name
                                Count = $record.Count
                            })
                    }
                }
            }
            finally {
                [Monitor]::Exit($state)
            }

            if ($byName) {
                return $count
            }

            return $copies.ToArray()
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
