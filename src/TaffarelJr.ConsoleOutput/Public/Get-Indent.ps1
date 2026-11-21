function Get-Indent {
    <#
    .SYNOPSIS
        Returns the current indent as spaces, ready to put in front of a line.
    .DESCRIPTION
        As many spaces as the widths pushed by Push-Indent or Invoke-Indented
        and not yet taken off add up to. An empty string when nothing is
        pushed. Get-IndentSize returns the same indent as a number.
    .INPUTS
        None.
    .OUTPUTS
        System.String. The indent, as spaces.
    .EXAMPLE
        Push-Indent
        Write-Host "$(Get-Indent)nested line"
        Pop-Indent

        Prints the line two spaces in, then takes the level off again.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-IndentSize
    .LINK
        Push-Indent
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return ' ' * $script:IndentSize
}
