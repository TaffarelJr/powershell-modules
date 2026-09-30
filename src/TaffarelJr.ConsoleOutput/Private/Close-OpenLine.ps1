function Close-OpenLine {
    <#
    .SYNOPSIS
        Ends a line left open by Write-Doing, if one is open.
    .DESCRIPTION
        Every other writer in this module calls it first,
        so a warning, a skip, or a failure from this module that interrupts
        a "Doing" line starts its own line instead of running on to the end
        of it. Output from anywhere else - Write-Warning, a native command,
        pipeline output reaching the host - never comes through here.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'Writing to the host is what this module is for.')]
    param()

    if (-not $script:LineOpen) {
        return
    }

    Write-Host ''
    $script:LineOpen = $false
}
