function Get-IndentLevel {
    <#
    .SYNOPSIS
        Returns a copy of the indent stack's levels, most recent first.
    .DESCRIPTION
        Not exported. One of the helpers that own the indent stack. The copy
        is what Restore-IndentLevel takes to put the stack back exactly as it
        was.
    .OUTPUTS
        The widths, one at a time.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    return $script:IndentStack.ToArray()
}
