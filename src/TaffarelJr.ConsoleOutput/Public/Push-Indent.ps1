function Push-Indent {
    <#
    .SYNOPSIS
        Starts an indented region -
        every writer below it picks up the new indent automatically,
        with no need to pass it around.
    .PARAMETER Width
        Spaces added by this level.
        Pop-Indent removes exactly this value,
        so nested levels can each use a different width safely.
    .EXAMPLE
        Push-Indent
        Write-Info 'nested line'
        Pop-Indent
    #>
    param(
        [Parameter(Position = 0)]
        [int]$Width = $script:DefaultIndentWidth
    )

    $script:IndentStack.Push($Width)
}
