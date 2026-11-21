function Get-IndentSize {
    <#
    .SYNOPSIS
        Returns the current indent as a number of spaces.
    .DESCRIPTION
        The sum of every width pushed by Push-Indent or Invoke-Indented and
        not yet taken off. Zero when nothing is pushed. Get-Indent returns the
        same indent as the spaces themselves.
    .INPUTS
        None.
    .OUTPUTS
        System.Int32. The indent, in spaces.
    .EXAMPLE
        Push-Indent -Width 4
        Get-IndentSize
        Pop-Indent

        Returns 4, the width of the one level pushed.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Get-Indent
    .LINK
        Push-Indent
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    return $script:IndentSize
}
