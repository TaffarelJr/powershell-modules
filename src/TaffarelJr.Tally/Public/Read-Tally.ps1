using namespace System.Globalization

function Read-Tally {
    <#
    .SYNOPSIS
        Parses a line produced by Format-Tally back into named counts -
        the counterpart that closes the round trip.
    .DESCRIPTION
        Whatever module prints a tally is also the module best placed
        to read one back, so a caller never hardcodes
        Format-Tally's text shape.
        A part that does not look like "<count> <name>" - including a count
        too large to hold - is skipped rather than thrown on, and nothing
        says it was. Any line that does - "3 warnings found" included - is
        read as a tally, so pick out the tally lines before piping a whole
        log in.

        The text is split on the separator alone, so a part is read only
        when it sits on one line: in text of several lines, a part that runs
        across a line break is skipped, and the parts that fit on a line are
        kept. Give it one line at a time, as Get-Content pipes them.
    .PARAMETER Text
        A line produced by Format-Tally. Lines can be piped in, each one
        read in turn.
    .PARAMETER Separator
        Must match whatever Format-Tally used to join the line.
        Defaults to ' - ', Format-Tally's own default.
    .INPUTS
        System.String. A line produced by Format-Tally.
    .OUTPUTS
        System.Management.Automation.PSCustomObject. One Name/Count object per
        entry it could read, its Count a [long], in the order they appear;
        text it could not read gives none. Wrap the call in @() to collect
        them as an array.
    .EXAMPLE
        Read-Tally -Text '3 passed - 1 failed'

        Returns two Name/Count objects: passed with 3 and failed with 1.
    .EXAMPLE
        Get-Content -LiteralPath 'build.log' -Tail 1 | Read-Tally | Add-Tally

        Adds the tally line a build printed last to this process's counters.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.Tally/README.md
    .LINK
        Format-Tally
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text,

        [ValidateNotNullOrEmpty()]
        [string]$Separator = ' - '
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            foreach ($part in ($Text -split [regex]::Escape($Separator))) {
                if ($part.Trim() -match '^(?<Count>-?[0-9]+)\s+(?<Name>\S(?:.*\S)?)$') {
                    $count = [long]0
                    $parsed = [long]::TryParse(
                        $Matches['Count'],
                        [NumberStyles]::AllowLeadingSign,
                        [CultureInfo]::InvariantCulture,
                        [ref]$count)
                    if ($parsed) {
                        [PSCustomObject]@{
                            Name  = $Matches['Name']
                            Count = $count
                        }
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
