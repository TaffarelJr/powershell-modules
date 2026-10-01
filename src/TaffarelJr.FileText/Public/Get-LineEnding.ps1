function Get-LineEnding {
    <#
    .SYNOPSIS
        Returns the line ending already used in a piece of text.
    .DESCRIPTION
        Whichever of CRLF and bare LF the text uses more often, so a file with
        a stray odd line is not converted wholesale to the odd one out; a tie
        goes to CRLF. A CRLF's own LF is not counted as a bare one.
        Falls back to this process's own default
        only for content that carries no line ending to read at all,
        such as a brand new file. A bare CR, the classic Mac OS ending, is
        not counted, so text that uses only that gets the fallback too.
    .PARAMETER Content
        The text to inspect.
    .INPUTS
        None. The text is given with -Content.
    .OUTPUTS
        System.String. The line ending: CRLF or LF, or this process's own
        default when the text has none.
    .EXAMPLE
        Get-LineEnding -Content (Get-Content -Raw -LiteralPath ./README.md)

        Returns "`r`n" when README.md has at least as many CRLF endings as bare
        LF ones, "`n" when it has more bare LF ones, and this process's own
        line ending when it has neither.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.FileText/README.md
    .LINK
        Read-TextFile
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string]$Content
    )

    try {
        $ErrorActionPreference = 'Stop'

        $crlf = [regex]::Matches($Content, "`r`n").Count
        $lf = [regex]::Matches($Content, "(?<!`r)`n").Count
        if ($crlf -eq 0 -and $lf -eq 0) {
            return [Environment]::NewLine
        }

        if ($crlf -ge $lf) {
            return "`r`n"
        }

        return "`n"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
    }
}
