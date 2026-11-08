function Get-RunExitCode {
    <#
    .SYNOPSIS
        Returns the exit code for a run: the number of failed files, held to
        255.
    .DESCRIPTION
        An exit status holds no more than 255; a bigger count would wrap around,
        and 256 failed files would end the run with 0 - a pass.
    .PARAMETER FailedCount
        How many files failed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange('NonNegative')]
        [int]$FailedCount
    )

    return [Math]::Min($FailedCount, 255)
}
