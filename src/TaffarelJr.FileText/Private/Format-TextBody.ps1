function Format-TextBody {
    <#
    .SYNOPSIS
        Joins lines into the text a file is written with.
    .DESCRIPTION
        Not exported. The lines are joined with the line ending and the text
        ends with exactly one. A line break inside a line - CRLF, LF or a lone
        CR - becomes the line ending too, so the text never holds two kinds.
        One break at the very end of the last line is dropped, since the
        ending that closes the text stands in for it. No lines make empty
        text, not one bare line ending.
    .PARAMETER Line
        The lines.
    .PARAMETER LineEnding
        The line ending to use, CRLF or LF.
    .OUTPUTS
        The text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Line,

        [Parameter(Mandatory)]
        [string]$LineEnding
    )

    if ($Line.Count -eq 0) {
        return ''
    }

    $all = [string[]]$Line.Clone()
    $all[-1] = $all[-1] -replace '(\r\n|\r|\n)\z', ''
    $joined = $all -join "`n"
    return ($joined -replace '\r\n|\r|\n', $LineEnding) + $LineEnding
}
