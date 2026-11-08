using namespace System.Diagnostics.CodeAnalysis
using namespace System.Linq

function Write-Box {
    <#
    .SYNOPSIS
        Renders text left-justified inside a rule (Header)
        or a full border (Banner) -
        the shared engine behind Write-Header, Write-Banner and Write-Step.
    .DESCRIPTION
        Not exported. A blank line is written before and after the box,
        setting it apart from whatever comes before or after it.
        Blank text is replaced by a placeholder,
        as in the other message writers.
        Lines are fitted by what shows on screen,
        so color codes in the text do not count toward the box's width,
        and a bordered line is padded out to the right border;
        a header's lines end with their text.
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
    [CmdletBinding()]
    [SuppressMessageAttribute(
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
    $indent = ' ' * (Get-AmbientIndent)
    $overhead = if ($Bordered) { 4 } else { 2 }
    $maxContentWidth = [Math]::Max(0, (Get-ConsoleWidth) - $indent.Length - $overhead)

    $message = Format-MessageText $Text
    $naturalLines = @(Split-WrappedLine -Text $message -Width $maxContentWidth)
    $lengths = [int[]]@(foreach ($line in $naturalLines) { Get-VisibleLength -Text $line })
    $longest = [Enumerable]::Max($lengths)
    $contentWidth = if ($Trim) { $longest } else { [Math]::Max($longest, $maxContentWidth) }

    Write-Host ''

    if ($Bordered) {
        Write-Host "${indent}┌$('─' * ($contentWidth + 2))┐" -ForegroundColor $color

        for ($i = 0; $i -lt $naturalLines.Count; $i++) {
            $padding = [Math]::Max(0, $contentWidth - $lengths[$i])
            Write-Host "${indent}│ $($naturalLines[$i])$(' ' * $padding) │" -ForegroundColor $color
        }

        Write-Host "${indent}└$('─' * ($contentWidth + 2))┘" -ForegroundColor $color
    }
    else {
        $rule = '─' * $contentWidth
        Write-Host "${indent}$rule" -ForegroundColor $color

        foreach ($line in $naturalLines) {
            Write-Host "${indent}$line" -ForegroundColor $color
        }

        Write-Host "${indent}$rule" -ForegroundColor $color
    }

    Write-Host ''
}
