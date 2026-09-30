function Write-Box {
    <#
    .SYNOPSIS
        Renders text centered inside a rule (Header)
        or a full border (Banner) -
        the shared engine behind both public functions.
    .PARAMETER Bordered
        Draws corners and a side character on every line (Banner).
        Without it, only the top and bottom rule are drawn (Header).
    #>
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

    $naturalLines = Split-WrappedLine -Text $Text -Width $maxContentWidth
    $contentWidth = $maxContentWidth
    if ($Trim) {
        $longest = ($naturalLines | Measure-Object -Property Length -Maximum).Maximum
        $contentWidth = [Math]::Min($longest, $maxContentWidth)
    }

    $centeredLines = foreach ($line in $naturalLines) {
        $extra = [Math]::Max(0, $contentWidth - $line.Length)
        $left = [Math]::Floor($extra / 2)
        $right = $extra - $left
        (' ' * $left) + $line + (' ' * $right)
    }

    if ($Bordered) {
        Write-Host "${indent}┌$('─' * ($contentWidth + 2))┐" -ForegroundColor $color

        foreach ($line in $centeredLines) {
            Write-Host "${indent}│ $line │" -ForegroundColor $color
        }

        Write-Host "${indent}└$('─' * ($contentWidth + 2))┘" -ForegroundColor $color
    }
    else {
        $rule = '─' * $contentWidth
        Write-Host "${indent}$rule" -ForegroundColor $color

        foreach ($line in $centeredLines) {
            Write-Host "${indent}$line" -ForegroundColor $color
        }

        Write-Host "${indent}$rule" -ForegroundColor $color
    }
}
