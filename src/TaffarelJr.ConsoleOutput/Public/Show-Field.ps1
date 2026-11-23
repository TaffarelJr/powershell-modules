function Show-Field {
    <#
    .SYNOPSIS
        Prints a name and its value on one line, as "Name: value".
    .DESCRIPTION
        Writes the name, a colon, and the value in gray, at the current indent.
        With -Budget the value starts in the same column on every line,
        so a run of fields lines up.
        A value is shown as the text PowerShell makes of it:
        an array is its elements separated by spaces,
        a hashtable is its type name, and $null is nothing.
        A line break in a value is written as it is,
        and the lines after the first are not lined up.
        A line with no value has no trailing spaces.
        If a line was left open, it is ended first.
    .PARAMETER Name
        The name to print. It is also read from a Key property,
        which is what the entries of a dictionary have.
    .PARAMETER Value
        The value to print. It may be $null or empty.
    .PARAMETER Budget
        The width of the name column.
        A shorter name is padded after its colon to this width.
        A longer name is not cut: its value starts one space after the colon.
        Without it, the value follows the colon after one space.
    .INPUTS
        System.Object. Anything with a Name or Key property and a Value
        property, such as the entries of a dictionary; each is printed in turn.
    .OUTPUTS
        None. The line is written to the host.
    .EXAMPLE
        Show-Field 'Branch' 'main'

        Prints "Branch: main" in gray.
    .EXAMPLE
        $fields = [ordered]@{ Branch = 'main'; 'Remote URL' = 'origin' }
        $fields.GetEnumerator() | Show-Field -Budget 10

        Prints the two fields with their values in the same column.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-Indent
    .LINK
        Show-Info
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias('Key')]
        [string]$Name,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [object]$Value,

        [ValidateRange('Positive')]
        [int]$Budget
    )

    process {
        $padding = [Math]::Max(0, $Budget - $Name.Length)
        $line = "$(Get-Indent)${Name}:$(' ' * $padding) $Value"
        Show-LineBreak
        Write-Host $line.TrimEnd() -ForegroundColor Gray
    }
}
