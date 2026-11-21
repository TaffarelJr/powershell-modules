function Invoke-Indented {
    <#
    .SYNOPSIS
        Runs a script block with an indented region active,
        putting the indent back where it started even if the block throws.
    .DESCRIPTION
        Calls Push-Indent, runs the script block, and calls Pop-Indent, even
        when the block throws. An error the block throws reaches the caller,
        after the indent is back. A block that pushes or pops levels of its
        own should leave them balanced.
        The block runs in the caller's own scope, as ForEach-Object's does,
        so a variable it assigns is the caller's variable.
    .PARAMETER ScriptBlock
        The code to run with the indent active.
    .PARAMETER Width
        Spaces added for the duration of the script block. See Push-Indent.
    .INPUTS
        None.
    .OUTPUTS
        System.Object. Whatever the script block writes, one item at a time.
    .EXAMPLE
        Invoke-Indented { Get-IndentSize }

        Returns 2, the indent while the block runs; afterward the indent is
        what it was before.
    .EXAMPLE
        Invoke-Indented -Width 4 { Invoke-Indented { Get-IndentSize } }

        Returns 6: the block's level and the nested block's add together.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Push-Indent
    .LINK
        Pop-Indent
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position = 1)]
        [ValidateRange('NonNegative')]
        [int]$Width = $script:IndentWidth
    )

    Push-Indent -Width $Width
    try {
        # Dot-sourced: with & the block gets a scope of its own, and its
        # assignments would be lost when it ends.
        . $ScriptBlock
    }
    finally {
        Pop-Indent
    }
}
