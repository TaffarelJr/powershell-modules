function Show-Box {
    <#
    .SYNOPSIS
        Prints text between two rules, or inside a full box, in cyan, at the
        current indent.
    .DESCRIPTION
        Not exported. The drawing shared by Show-Header and Show-Banner. A
        blank line is written before and after, setting the box apart from
        what surrounds it. The rules or the box span the console less the
        indent, and are never narrower than the widest line of the text. Text
        is not wrapped. A line left open is ended first. This command gathers
        what it needs from the host and writes the lines; Get-BoxContentWidth,
        Get-BoxFrame and Format-BoxLine decide the width, the frame and the
        padding.
    .PARAMETER Text
        The text to print. A line break starts a new line.
    .PARAMETER Trim
        Shrinks the rules or the box to the widest line of the text instead of
        spanning the console.
    .PARAMETER Bordered
        Draws a full box with a side character on every line, as Show-Banner
        does. Without it, only a rule above and a rule below, as Show-Header
        does. A bordered line is padded on the right out to the side
        character.
    .PARAMETER Centered
        Centers each line of the text within the rules or the box. Without it,
        each line starts at the left edge. When a line cannot be centered
        exactly, the extra column goes on the right. Independent of -Bordered.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [switch]$Trim,

        [switch]$Bordered,

        [switch]$Centered
    )

    $indent = Get-Indent
    $lines = @($Text -split '\r\n|\r|\n')

    $widthArguments = @{
        Line         = $lines
        ConsoleWidth = Get-ConsoleWidth
        IndentLength = $indent.Length
        Trim         = $Trim
        Bordered     = $Bordered
    }
    $width = Get-BoxContentWidth @widthArguments
    $frame = Get-BoxFrame -Indent $indent -ContentWidth $width -Bordered:$Bordered

    Show-LineBreak
    Write-Host ''
    Write-Host $frame.Top -ForegroundColor Cyan
    $lineArguments = @{
        ContentWidth = $width
        Centered     = $Centered
        Bordered     = $Bordered
    }
    foreach ($line in $lines) {
        $text = Format-BoxLine -Line $line @lineArguments
        Write-Host "$($frame.Lead)$text$($frame.Trail)" -ForegroundColor Cyan
    }

    Write-Host $frame.Bottom -ForegroundColor Cyan
    Write-Host ''
}
