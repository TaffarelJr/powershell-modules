function Show-Banner {
    <#
    .SYNOPSIS
        Prints text centered inside a full box, for an announcement.
    .DESCRIPTION
        Writes a blank line, a box with a side character on every line, and
        another blank line, all in cyan, at the current indent. Each line of
        the text is centered on its own; when it cannot be centered exactly,
        the extra column goes on the right. The box spans the console less
        the indent, or 80 columns when there is no window to measure or
        standard output is redirected. A line break in the text starts a new
        line. Text is not wrapped: a line wider than the box widens it. Width
        is counted in characters, so wide characters, emoji and color codes in
        the text can push the right border out of line.
    .PARAMETER Text
        The text to print. A line break starts a new line.
    .PARAMETER Trim
        Shrinks the box to the widest line of the text instead of spanning
        the console.
    .INPUTS
        System.String. The text to print; each one is boxed in turn.
    .OUTPUTS
        None. The box is written to the host.
    .EXAMPLE
        Show-Banner 'BUILD FAILED'

        Prints the text centered inside a box as wide as the console.
    .EXAMPLE
        Show-Banner 'BUILD FAILED' -Trim

        Prints the text inside a box as wide as the text.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-Indent
    .LINK
        Show-Header
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text,

        [switch]$Trim
    )

    process {
        Show-Box -Text $Text -Trim:$Trim -Bordered -Centered
    }
}
