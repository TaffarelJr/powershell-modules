function Get-BoxContentWidth {
    <#
    .SYNOPSIS
        Returns how many columns of text a box's rules or sides enclose.
    .DESCRIPTION
        Not exported. With -Trim, the width of the widest line. Otherwise the
        console's width less the indent and the columns the frame itself takes
        (2 for a rule, 4 for a bordered box), or the widest line when that is
        wider. A line is never wrapped, so a line wider than the console
        widens the result.
    .PARAMETER Line
        The lines of text to enclose.
    .PARAMETER ConsoleWidth
        The console's width in columns.
    .PARAMETER IndentLength
        How many columns the indent takes.
    .PARAMETER Trim
        Returns the width of the widest line, whatever the console's width.
    .PARAMETER Bordered
        The frame is a full box, with a side character and a space on each
        side of every line, rather than two rules.
    .OUTPUTS
        The width in columns.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Line,

        [Parameter(Mandatory)]
        [int]$ConsoleWidth,

        [Parameter(Mandatory)]
        [int]$IndentLength,

        [switch]$Trim,

        [switch]$Bordered
    )

    $longest = 0
    foreach ($text in $Line) {
        if ($text.Length -gt $longest) {
            $longest = $text.Length
        }
    }

    if ($Trim) {
        return $longest
    }

    $overhead = 2
    if ($Bordered) {
        $overhead = 4
    }

    return [Math]::Max($longest, $ConsoleWidth - $IndentLength - $overhead)
}
