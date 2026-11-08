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
        A name with line breaks prints its earlier lines on their own,
        and its last line leads the value.
        Color codes in the name take no room in the column.
    .PARAMETER Value
        What follows the name: text, or anything that prints as text.
        A value with embedded line breaks, or a list of values,
        puts each later line under the first one;
        a list inside the list is printed item by item too.
        A dictionary prints one "key = value" line for each entry, sorted by
        the key's text, so a hashtable lists its contents instead of its type
        name; a list held by an entry is joined with commas.
    .PARAMETER Budget
        Columns from the indent to where the value starts,
        the separating space included;
        a longer name pushes its value out of the column,
        and the later lines of the value start under it.
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
        [int]$Budget = 15
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            Write-FieldLine -Name $Name -Value $Value -Budget $Budget
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
