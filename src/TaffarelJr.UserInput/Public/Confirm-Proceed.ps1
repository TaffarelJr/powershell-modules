function Confirm-Proceed {
    <#
    .SYNOPSIS
        Returns $true when the run should continue - the final go/no-go gate.
    .DESCRIPTION
        Requires the word 'yes', in any casing,
        rather than accepting anything truthy:
        a gate that a stray keypress can pass is not a gate.
        No retry - a wrong answer is a final no,
        reported through Write-Warn so it looks like every other warning.

        For a lighter, re-askable yes/no question, see Confirm-Input instead.
    .PARAMETER Action
        What is about to happen, completing "Type 'yes' to ...".
    #>
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Action
    )

    if ((Read-Host "  Type 'yes' to $Action") -eq 'yes') {
        return $true
    }

    Write-Warn 'Aborted by user'
    return $false
}
