using namespace System.Collections.Generic
using namespace System.Threading

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

        Every count it shows is the module's own counter for the name,
        whatever was piped in: an object only names a counter, so its Count
        is not read. Read-Tally '5 passed' | Format-Tally shows 0 passed.
        To show counts read from text, merge them first, with
        Read-Tally | Add-Tally.

        Throws if Read-Tally could not split the line back into the same
        entries: when the separator appears inside an entry, in its count or
        its name, or is made across the join between two entries, as
        "1 a -" followed by "1 c" makes " - " twice. Pass a different
        -Separator. Any other failure, such as a name that cannot be one,
        ends the call the same way: with a terminating error and no line.
    .PARAMETER Name
        Which counters to include, and in what order: names, or objects
        whose Name property holds one, such as Get-Tally's output.
        Names and objects can be piped in too; everything piped in is
        rendered as one line, after the last one arrives, and a pipeline
        that delivers nothing renders nothing. A piped object's Count is
        not used: each count shown is the module's own for that name, so to
        show counts read from text, merge them with Read-Tally | Add-Tally
        first.
        Omit it, with nothing piped in, to include every counter,
        in the order each name was first added.
        A name no counter could have, such as an empty one, is refused.
        Names that came from another command - Get-Tally -Key K, say - need
        the same -Key here: the key does not travel with them.
    .PARAMETER Separator
        Joins each "<Count> <Name>" part together. Defaults to ' - '.
    .PARAMETER Key
        Renders this namespace instead of the shared, global counters -
        see Add-Tally. A $null, empty or blank key is refused rather than
        taken to mean the global counters.
    .INPUTS
        System.Object. A name, or an object with a Name property, such as
        Get-Tally's output; all of them are rendered as one line.
    .OUTPUTS
        System.String. The counters as one line, "<Count> <Name>" joined by
        the separator.
    .EXAMPLE
        Format-Tally -Name @('passed', 'failed', 'crashed')

        Returns "3 passed - 1 failed - 0 crashed" when those are the counts,
        with crashed shown at zero because it was asked for.
    .EXAMPLE
        Get-Tally | Format-Tally -Separator ', '

        Renders every counter, in the order each was first added, joined by
        commas.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/README.md
    .LINK
        Read-Tally
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [object[]]$Name,

        [ValidateNotNullOrEmpty()]
        [string]$Separator = ' - ',

        [ValidatePattern(
            '\S',
            ErrorMessage = 'A tally key must hold a non-blank character; omit -Key for the global counters.'
        )]
        [string]$Key
    )

    begin {
        try {
            $ErrorActionPreference = 'Stop'

            $requested = [List[string]]::new()
            $nameGiven = $PSBoundParameters.ContainsKey('Name') -or $MyInvocation.ExpectingInput
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    process {
        try {
            if ($PSBoundParameters.ContainsKey('Name')) {
                foreach ($entryName in $Name) {
                    $requested.Add((Resolve-TallyName -InputObject $entryName))
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }

    end {
        try {
            $state = Get-TallyState
            [Monitor]::Enter($state)
            try {
                $tallies = Get-TallyBucket -Key $Key
                $names = @($requested)
                if (-not $nameGiven) {
                    $names = @()
                    if ($null -ne $tallies) {
                        # PSBase: a counter named Values would otherwise be
                        # read in place of every counter.
                        $names = @($tallies.PSBase.Values | ForEach-Object { $_.Name })
                    }
                }

                $parts = [List[string]]::new()
                foreach ($entryName in $names) {
                    $count = 0
                    $shown = $entryName
                    if ($null -ne $tallies -and $tallies.Contains($entryName)) {
                        $count = $tallies[$entryName].Count
                        $shown = $tallies[$entryName].Name
                    }

                    $parts.Add("$count $shown")
                }
            }
            finally {
                [Monitor]::Exit($state)
            }

            $line = $parts -join $Separator
            $pieces = $line -split [regex]::Escape($Separator)
            for ($i = 0; $i -lt $parts.Count; $i++) {
                if ($i -ge $pieces.Count -or $pieces[$i] -cne $parts[$i]) {
                    throw "The tally entry '$($parts[$i])' would not read back: " +
                        "the separator '$Separator' appears in it, or across its join with the next entry. " +
                        'Pass a different -Separator.'
                }
            }

            return $line
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
