function Invoke-Indented {
    <#
    .SYNOPSIS
        Runs a script block with an indented region active,
        guaranteeing the indent is popped even if the block throws.
    .PARAMETER ScriptBlock
        The code to run with the indent active.
    .PARAMETER Width
        Spaces added for the duration of the script block. See Push-Indent.
    .EXAMPLE
        Invoke-Indented { Write-Info 'nested line' }
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [scriptblock]$ScriptBlock,

        [Parameter(Position = 1)]
        [int]$Width = $script:DefaultIndentWidth
    )

    Push-Indent -Width $Width
    try {
        & $ScriptBlock
    }
    finally {
        Pop-Indent
    }
}
