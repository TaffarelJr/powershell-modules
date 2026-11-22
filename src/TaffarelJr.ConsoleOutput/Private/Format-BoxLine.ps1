function Format-BoxLine {
    <#
    .SYNOPSIS
        Returns one line of a box's text, padded to sit where it belongs.
    .DESCRIPTION
        Not exported. With -Centered the line is moved right by half the
        spare columns, rounded down, so when the spare columns are odd the
        extra one is on the right. With -Bordered the line is padded on the
        right out to the box's side character. With neither, the line is
        returned as it is.
    .PARAMETER Line
        The line of text.
    .PARAMETER ContentWidth
        The width of the text area. It must be at least the length of the
        line.
    .PARAMETER Centered
        Center the line within the text area.
    .PARAMETER Bordered
        Pad the line on the right out to the edge of the text area.
    .OUTPUTS
        The line with its padding.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Line,

        [Parameter(Mandatory)]
        [int]$ContentWidth,

        [switch]$Centered,

        [switch]$Bordered
    )

    $spare = $ContentWidth - $Line.Length

    $left = 0
    if ($Centered) {
        $left = [int][Math]::Floor($spare / 2)
    }

    $right = 0
    if ($Bordered) {
        $right = $spare - $left
    }

    return "$(' ' * $left)$Line$(' ' * $right)"
}
