function Pop-Indent {
    <#
    .SYNOPSIS
        Ends the most recently started indented region.
    .DESCRIPTION
        Takes the latest level off the indent this module keeps for the
        current runspace. Warns rather than throwing when there is nothing to
        pop - a caller bug, but not one that should crash a run over a
        cosmetic mismatch. -WarningAction SilentlyContinue hides the warning,
        and Stop makes it an error.
    .INPUTS
        None.
    .OUTPUTS
        None. The indent shrinks; nothing is returned.
    .EXAMPLE
        Push-Indent
        Pop-Indent
        Get-IndentSize

        Returns 0: the pop took off the level the push added.
    .LINK
        https://github.com/TaffarelJr/powershell-modules/blob/main/src/TaffarelJr.ConsoleOutput/README.md
    .LINK
        Push-Indent
    #>
    [CmdletBinding()]
    param()

    if ($script:IndentStack.Count -gt 0) {
        $script:IndentSize -= $script:IndentStack.Pop()
    }
    else {
        Write-Warning 'Pop-Indent called with no matching Push-Indent.'
    }
}
