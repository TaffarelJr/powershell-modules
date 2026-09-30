function Get-Indent {
    <#
    .SYNOPSIS
        Returns the current ambient indent, in spaces.
    .DESCRIPTION
        The sum of every width pushed by Push-Indent and not yet popped.
        Zero when nothing is pushed.
    #>
    [CmdletBinding()]
    param()

    $total = 0
    foreach ($width in $script:IndentStack) {
        $total += $width
    }

    return $total
}
