function Show-Outcome {
    <#
    .SYNOPSIS
        Writes how a piece of work went: at the end of the open line when
        there is one, on a line of its own when there is not.
    .DESCRIPTION
        Not exported. Shared by Show-Done and Invoke-Doing. With a line open,
        writes a space and the wording in the outcome's color, which ends the
        line. With none open, the outcome is written by the status command
        that matches it, so its marker and color are the ones that command
        uses, and a caller does not have to track whether a line is open.
    .PARAMETER Outcome
        How it went: Success, Skip, Warn, Failure or Stopped. A stopped
        outcome is written as a warning.
    .PARAMETER Text
        The wording. Blank or missing uses the outcome's own: "done",
        "already done", "warning", "failed" or "stopped".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Failure', 'Skip', 'Stopped', 'Success', 'Warn')]
        [string]$Outcome,

        [string]$Text
    )

    $styles = @{
        Failure = @{ Color = 'Red'; Wording = 'failed'; Writer = 'Show-Failure' }
        Skip    = @{ Color = 'DarkGray'; Wording = 'already done'; Writer = 'Show-Skip' }
        Stopped = @{ Color = 'Yellow'; Wording = 'stopped'; Writer = 'Show-Warning' }
        Success = @{ Color = 'Green'; Wording = 'done'; Writer = 'Show-Success' }
        Warn    = @{ Color = 'Yellow'; Wording = 'warning'; Writer = 'Show-Warning' }
    }
    $style = $styles[$Outcome]

    $wording = $Text
    if ([string]::IsNullOrWhiteSpace($wording)) {
        $wording = $style.Wording
    }

    if ($script:LineOpen) {
        $script:LineOpen = $false
        Write-Host " $wording" -ForegroundColor $style.Color
        return
    }

    & $style.Writer -Text $wording
}
