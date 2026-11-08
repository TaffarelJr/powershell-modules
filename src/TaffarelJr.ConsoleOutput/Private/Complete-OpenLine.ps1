function Complete-OpenLine {
    <#
    .SYNOPSIS
        Ends the line Write-Doing left open with an outcome, or writes that
        outcome as a line of its own when no line is open.
    .DESCRIPTION
        Not exported. The one place a Doing line is finished with how it
        went: the outcome follows the open line's text, in the outcome's
        color, and a later line of a multi-line outcome sits under that text.
        With no line open the outcome becomes a marker line, as Write-Success,
        Write-Skip, Write-Warn or Write-Failure would print it, so a caller
        does not have to track whether one is open.
    .PARAMETER Outcome
        Which outcome: its color, its marker and its default wording come from
        Get-OutcomeStyle.
    .PARAMETER Text
        The outcome's wording. A blank one uses the outcome's default.
    .PARAMETER Line
        The number Open-DoingLine returned for the line this outcome belongs
        to. When another line is open instead (one the caller's own work
        opened), that line is ended and the outcome becomes a marker line, so
        it never lands on the wrong step. Without it, whatever line is open is
        finished.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Outcome,

        [string]$Text,

        [int]$Line
    )

    $style = Get-OutcomeStyle -Outcome $Outcome
    $wording = if ([string]::IsNullOrWhiteSpace($Text)) {
        $style.Wording
    }
    else {
        $Text
    }

    $ours = -not $PSBoundParameters.ContainsKey('Line') -or $Line -eq $script:LineNumber
    if (-not $script:LineOpen -or -not $ours) {
        Write-MarkerLine -Text $wording -Outcome $Outcome
        return
    }

    $message = Format-MessageText $wording
    $script:LineOpen = $false
    Write-MessageLine -Lead ' ' -Continuation $script:OpenLineContinuation `
        -Text $message -Color $style.Color
}
