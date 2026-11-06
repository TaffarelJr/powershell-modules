function Write-Field {
    <#
    .SYNOPSIS
        Prints an aligned name/value line.
    .DESCRIPTION
        Writes the name, a colon, and the value in gray, with every value
        starting in the same column, so successive fields read as a table.
        A line left open by Write-Doing is ended first.
    .PARAMETER Name
        May be empty, which prints the value alone,
        continuing the field above.
    .PARAMETER Value
        What follows the name: text, or anything that prints as text.
        A value with embedded line breaks, or a list of values,
        puts each later line under the first one.
        A dictionary prints one "key = value" line for each entry, sorted by
        the key's text, so a hashtable lists its contents instead of its type
        name.
    .PARAMETER Budget
        Columns from the indent to where the value starts,
        the separating space included;
        a longer name pushes its value out of the column,
        and the later lines of the value start under it.
    .PARAMETER Indent
        Overrides the ambient indent (see Push-Indent) for this line only.
    .INPUTS
        System.Object. An object with Name and Value properties, bound by
        property name. A plain string has neither and is not accepted.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        [PSCustomObject]@{ Name = 'Branch'; Value = 'main' } | Write-Field

        Binds Name/Value by property name,
        so a stream of name/value objects can be piped straight through.
    .EXAMPLE
        Write-Field 'Paths' @('src', 'test')

        Prints each path on its own line, lined up under the first.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Write-Info
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [object]$Value,

        [ValidateRange('Positive')]
        [int]$Budget = 15,

        [ValidateRange('NonNegative')]
        [int]$Indent = -1
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            Close-OpenLine
            $prefix = Format-LineIndent -Indent $Indent
            $field = if ($Name) {
                "${Name}:".PadRight($Budget - 1)
            }
            else {
                ' ' * ($Budget - 1)
            }

            $text = if ($Value -is [System.Collections.IDictionary]) {
                # Enumerate the entries instead of indexing by key: an ordered
                # dictionary reads an integer index as a position, not a key.
                $pairs = @($Value.GetEnumerator())
                $keys = [string[]]@($pairs.ForEach({ "$($_.Key)" }))
                $entries = [string[]]@($pairs.ForEach({ "$($_.Key) = $($_.Value)" }))
                [Array]::Sort($keys, $entries, [StringComparer]::Ordinal)
                $entries -join "`n"
            }
            elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
                @($Value) -join "`n"
            }
            else {
                "$Value"
            }

            $lead = "$prefix$field "
            Write-MessageLine -Lead $lead -Continuation (' ' * $lead.Length) -Text $text -Color Gray
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
