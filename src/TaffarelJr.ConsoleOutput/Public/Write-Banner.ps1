function Write-Banner {
    <#
    .SYNOPSIS
        Prints the given text left-justified inside a full box -
        corners, top and bottom, and a side character on every line -
        for a standalone announcement rather than a section introduction.
    .DESCRIPTION
        Writes a blank line, the box in cyan, and another blank line. The box
        spans the console less the ambient indent, and is never narrower than
        its text: a single word too long to fit widens it. A line left open
        by Write-Doing is ended first.
    .PARAMETER Text
        Embedded CR/LF starts a new line;
        a line too long for the console wraps at word boundaries
        instead of running past it. Width is counted in characters, so wide
        characters and emoji can push the right edge out of line;
        color codes take no room, but a color reset in the text also ends
        the banner's own color for the rest of that line.
        Blank text prints the "(no message)" placeholder.
    .PARAMETER Trim
        Shrinks the box to fit the longest line instead of the full
        console width.
        A no-op once the text already needs the full width.
    .INPUTS
        System.String. The text to print; each one is boxed in turn.
    .OUTPUTS
        None. The box is written to the host.
    .EXAMPLE
        Write-Banner 'BUILD FAILED'

        Prints the text inside a box as wide as the console.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Write-Header
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text,

        [switch]$Trim
    )

    process {
        try {
            $ErrorActionPreference = 'Stop'

            Write-Box -Text $Text -Trim:$Trim -Bordered
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
