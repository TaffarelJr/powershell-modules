function Write-Box {
    <#
    .SYNOPSIS
        Renders text left-justified inside a rule (Header)
        or a full border (Banner) -
        the shared engine behind both public functions.
    .DESCRIPTION
        A blank line is written before and after the box,
        setting it apart from whatever comes before or after it.
        Blank text is replaced by a placeholder,
        as in the other message writers.
        Lines are fitted and padded by what shows on screen,
        so color codes in the text do not count toward the box's width.
        The box is never narrower than its longest line:
        a word too long for the console widens it.
    .PARAMETER Text
        The text to put in the box.
    .PARAMETER Trim
        Shrinks the box to its longest line instead of the full console width.
    .PARAMETER Bordered
        Draws corners and a side character on every line (Banner).
        Without it, only the top and bottom rule are drawn (Header).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'Writing to the host is what this module is for.')]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [switch]$Trim,
        [switch]$Bordered
    )

    Close-OpenLine

    $color = 'Cyan'
    $indent = ' ' * (Get-Indent)
    $overhead = if ($Bordered) { 4 } else { 2 }
    $maxContentWidth = [Math]::Max(0, (Get-ConsoleWidth) - $indent.Length - $overhead)

    $message = Format-MessageText $Text
    $naturalLines = @(Split-WrappedLine -Text $message -Width $maxContentWidth)
    $lengths = foreach ($line in $naturalLines) {
        Get-VisibleLength -Text $line
    }
    $longest = [int]($lengths | Measure-Object -Maximum).Maximum
    $contentWidth = if ($Trim) { $longest } else { [Math]::Max($longest, $maxContentWidth) }

    $justifiedLines = foreach ($line in $naturalLines) {
        $padding = [Math]::Max(0, $contentWidth - (Get-VisibleLength -Text $line))
        $line + (' ' * $padding)
    }

    Write-Host ''

    if ($Bordered) {
        Write-Host "${indent}┌$('─' * ($contentWidth + 2))┐" -ForegroundColor $color

        foreach ($line in $justifiedLines) {
            Write-Host "${indent}│ $line │" -ForegroundColor $color
        }

        Write-Host "${indent}└$('─' * ($contentWidth + 2))┘" -ForegroundColor $color
    }
    else {
        $rule = '─' * $contentWidth
        Write-Host "${indent}$rule" -ForegroundColor $color

        foreach ($line in $justifiedLines) {
            Write-Host "${indent}$line" -ForegroundColor $color
        }

        Write-Host "${indent}$rule" -ForegroundColor $color
    }

    Write-Host ''
}
