function Get-LineEnding {
    <#
    .SYNOPSIS
        Returns the line ending already used in a piece of text.
    .DESCRIPTION
        Checked in this order because a CRLF file also matches a bare LF search -
        every "`n" is preceded by a "`r" in one, and is not in the other.
        Falls back to this process's own default
        only for content that carries no line ending to read at all,
        such as a brand new file.
    .PARAMETER Content
        The text to inspect.
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Content
    )

    if ($Content.Contains("`r`n")) {
        return "`r`n"
    }

    if ($Content.Contains("`n")) {
        return "`n"
    }

    return [Environment]::NewLine
}
