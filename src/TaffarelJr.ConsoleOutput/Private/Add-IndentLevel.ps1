function Add-IndentLevel {
    <#
    .SYNOPSIS
        Adds a level to the indent stack.
    .DESCRIPTION
        Not exported. One of the helpers that own the indent stack, so its
        shape is known in one place.
    .PARAMETER Width
        Spaces the level adds.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$Width
    )

    $script:IndentStack.Push($Width)
}
