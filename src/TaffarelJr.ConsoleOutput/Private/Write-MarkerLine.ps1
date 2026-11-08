function Write-MarkerLine {
    <#
    .SYNOPSIS
        Writes one status message in the marker and color of an outcome, at
        the current indent.
    .DESCRIPTION
        Not exported. The shared body of every outcome writer (Write-Success,
        Write-Skip, Write-Warn, Write-Failure, Write-Info, Write-Detail) and of
        an outcome printed on a line of its own: closes any open "Doing" line
        first, indents the message, and lines every later line of a multi-line
        message up under the first one's text. The marker, color and
        continuation all come from Get-OutcomeStyle.
    .PARAMETER Text
        The message. A blank one is replaced by a placeholder.
    .PARAMETER Outcome
        Which outcome's marker and color to use.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$Outcome
    )

    $style = Get-OutcomeStyle -Outcome $Outcome
    Close-OpenLine
    $prefix = Format-LineIndent
    $message = Format-MessageText $Text
    $lead = "$prefix$($style.Marker)"
    Write-MessageLine -Lead $lead -Continuation "$prefix$($style.Continuation)" -Text $message -Color $style.Color
}
