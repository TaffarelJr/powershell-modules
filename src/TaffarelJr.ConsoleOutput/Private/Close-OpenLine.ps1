function Close-OpenLine {
    <#
    .SYNOPSIS
        Ends a line left open by Write-Doing, if one is open.
    .DESCRIPTION
        Every other writer in this module calls it first,
        so a warning, a skip, or a failure that interrupts a "Doing" line
        starts its own line instead of running on to the end of it.
    #>
    if (-not $script:LineOpen) {
        return
    }

    Write-Host ''
    $script:LineOpen = $false
}
