function Split-TextLine {
    <#
    .SYNOPSIS
        Splits text at every line break: CRLF, a lone LF, or a lone CR.
    .DESCRIPTION
        Not exported. A lone CR counts too: printed as it is, it sends the
        cursor back to overwrite the start of the line, marker and all.
    .PARAMETER Text
        The text to split.
    .OUTPUTS
        The lines, one at a time - always at least one, even for empty text.
    #>
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    return $Text -split '\r\n|\r|\n'
}
