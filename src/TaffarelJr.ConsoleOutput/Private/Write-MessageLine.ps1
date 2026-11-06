function Write-MessageLine {
    <#
    .SYNOPSIS
        Writes text to the host one line per line of text, so a message with
        embedded line breaks keeps its indent on every line.
    .DESCRIPTION
        Not exported. The first line follows -Lead and every later line
        follows -Continuation; a blank later line is written bare,
        without the continuation.
    .PARAMETER Lead
        What starts the first line - the indent and any marker.
    .PARAMETER Continuation
        What starts each later line.
    .PARAMETER Text
        The message. Already made safe to print by the caller.
    .PARAMETER Color
        The foreground color of every line.
    .PARAMETER NoNewline
        Leaves the last line open, for a later write to finish.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'Writing to the host is what this module is for.')]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Lead,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Continuation,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [System.ConsoleColor]$Color,

        [switch]$NoNewline
    )

    $lines = @(Split-TextLine -Text $Text)
    $last = $lines.Count - 1
    for ($i = 0; $i -le $last; $i++) {
        $line = if ($i -eq 0) {
            "$Lead$($lines[0])"
        }
        elseif ($lines[$i]) {
            "$Continuation$($lines[$i])"
        }
        else {
            ''
        }

        $leaveOpen = $NoNewline -and $i -eq $last
        Write-Host $line -ForegroundColor $Color -NoNewline:$leaveOpen
    }
}
