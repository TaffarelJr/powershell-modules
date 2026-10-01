function Read-Tally {
    <#
    .SYNOPSIS
        Parses a line produced by Format-Tally back into named counts -
        the counterpart that closes the round trip.
    .DESCRIPTION
        Whatever module prints a tally is also the module best placed
        to read one back, so a caller never has to hardcode
        the text shape Format-Tally happens to use today.
        A part that doesn't look like "<count> <name>" is skipped
        rather than thrown on, since a caller may be scanning
        arbitrary captured output for the one line that is a real tally.
    .PARAMETER Text
        A line produced by Format-Tally.
    .PARAMETER Separator
        Must match whatever Format-Tally used to join the line.
        Defaults to ' - ', Format-Tally's own default.
    .EXAMPLE
        Read-Tally -Text '3 passed - 1 failed'
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Text,

        [string]$Separator = ' - '
    )

    $parts = $Text -split [Regex]::Escape($Separator)

    return , @(foreach ($part in $parts) {
            if ($part -match '^(?<Count>\d+)\s+(?<Name>.+)$') {
                [PSCustomObject]@{
                    Name  = $Matches['Name']
                    Count = [int]$Matches['Count']
                }
            }
        })
}
