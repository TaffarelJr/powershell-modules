function Show-LineBreak {
    <#
    .SYNOPSIS
        Ends a line that was left open, if one is.
    .DESCRIPTION
        Not exported. The one place the open-line state is cleared. Every
        command that writes a line of its own calls it first, so what it
        writes starts on a line of its own instead of running on to the end
        of an open one. Writes nothing when no line is open.
    #>
    [CmdletBinding()]
    param()

    if (-not $script:LineOpen) {
        return
    }

    $script:LineOpen = $false
    Write-Host ''
}
