function Test-GitHubGistBinary {
    <#
    .SYNOPSIS
        Returns whether text holds a control character that text never
        holds.
    .DESCRIPTION
        Binary means a control character below a space other than tab, line
        feed, form feed, carriage return, and escape. UTF-8 holds each of
        them as one byte, so the text decoded from a file and the same
        bytes read one to a character give the same answer.
    .PARAMETER Text
        The text to look through.
    .OUTPUTS
        $true when the text holds one.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    return $Text -match '[\x00-\x08\x0B\x0E-\x1A\x1C-\x1F]'
}
