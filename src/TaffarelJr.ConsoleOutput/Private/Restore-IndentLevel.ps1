function Restore-IndentLevel {
    <#
    .SYNOPSIS
        Puts the indent stack back to the levels Get-IndentLevel returned.
    .DESCRIPTION
        Not exported. One of the helpers that own the indent stack. Given no
        levels it empties the stack.
    .PARAMETER Level
        The widths, most recent first, as Get-IndentLevel returns them.
    #>
    [CmdletBinding()]
    param(
        [int[]]$Level = @()
    )

    $script:IndentStack.Clear()
    for ($i = $Level.Count - 1; $i -ge 0; $i--) {
        $script:IndentStack.Push($Level[$i])
    }
}
