function Show-Header {
    <#
    .SYNOPSIS
        Prints text between two rules, to introduce a section that follows.
    .DESCRIPTION
        Writes a blank line, a rule, the text left-justified, a closing rule
        and another blank line, all in cyan, at the current indent. The rules
        span the console less the indent and two columns, or 80 columns when
        there is no window to measure or standard output is redirected. A line
        break in the text starts a new line. Text is not wrapped: a line wider
        than the rules widens them. Width is counted in characters, so wide
        characters, emoji and color codes in the text can make the rules
        wider than the text shows.
    .PARAMETER Text
        The text to print. A line break starts a new line.
    .PARAMETER Trim
        Shrinks the rules to the widest line of the text instead of spanning
        the console.
    .INPUTS
        System.String. The text to print; each one is printed in turn.
    .OUTPUTS
        None. The header is written to the host.
    .EXAMPLE
        Show-Header 'Build'

        Prints the text between two rules as wide as the console.
    .EXAMPLE
        Show-Header 'Build' -Trim

        Prints the text between two rules as wide as the text.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-Indent
    .LINK
        Show-Banner
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text,

        [switch]$Trim
    )

    process {
        Show-Box -Text $Text -Trim:$Trim
    }
}
