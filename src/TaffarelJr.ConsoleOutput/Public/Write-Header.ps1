function Write-Header {
    <#
    .SYNOPSIS
        Prints a rule, the given text left-justified, and a closing rule -
        open sides, for introducing a section that follows.
    .DESCRIPTION
        Writes a blank line, the rules and the text in cyan, and another
        blank line. The rules span the console less the ambient indent, and
        are never narrower than the text: a single word too long to fit
        widens them. A line left open by Write-Doing is ended first.
    .PARAMETER Text
        Embedded CR/LF starts a new line;
        a line too long for the console wraps at word boundaries
        instead of running past it. Width is counted in characters, so wide
        characters and emoji can push the right edge out of line;
        color codes take no room, but a color reset in the text also ends
        the header's own color for the rest of that line.
        Blank text prints the "(no message)" placeholder.
    .PARAMETER Trim
        Shrinks the rule to fit the longest line instead of the full
        console width.
        A no-op once the text already needs the full width.
    .INPUTS
        System.String. The text to print; each one is printed in turn.
    .OUTPUTS
        None. The header is written to the host.
    .EXAMPLE
        Write-Header 'Build'

        Prints the text between two rules as wide as the console.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Write-Banner
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

            Write-Box -Text $Text -Trim:$Trim
        }
        catch {
            $PSCmdlet.ThrowTerminatingError(
                (ConvertTo-CommandError -ErrorRecord $_ -Command $MyInvocation.MyCommand.Name))
        }
    }
}
