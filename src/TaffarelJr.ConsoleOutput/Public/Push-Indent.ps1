function Push-Indent {
    <#
    .SYNOPSIS
        Starts an indented region by adding a level to the indent.
    .DESCRIPTION
        Adds a level to the indent this module keeps for the current
        runspace, and writes nothing. The level counts in what Get-Indent
        and Get-IndentSize return until Pop-Indent takes it off again.
        Invoke-Indented does both around a script block.
    .PARAMETER Width
        Spaces added by this level: 2 unless given,
        the value the exported DefaultIndentWidth shows.
        Pop-Indent removes exactly this value,
        so nested levels can each use a different width safely.
    .INPUTS
        None.
    .OUTPUTS
        None. The indent grows; nothing is returned.
    .EXAMPLE
        Push-Indent
        Push-Indent -Width 4
        Get-IndentSize
        Pop-Indent
        Pop-Indent

        Returns 6, the two levels together, then takes each level off again.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Pop-Indent
    .LINK
        Get-Indent
    .LINK
        Get-IndentSize
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateRange('NonNegative')]
        [int]$Width = $script:IndentWidth
    )

    $script:IndentStack.Push($Width)
    $script:IndentSize += $Width
}
