function Write-MarkerLine {
    <#
    .SYNOPSIS
        Writes one status message behind its marker, at the right indent.
    .DESCRIPTION
        Not exported. The shared body of every line printer that is just a
        marker, a color, and text: closes any open "Doing" line first, indents
        the message, and lines every later line of a multi-line message up under
        the first one's text. Three spaces carry a continuation past the marker
        - an emoji and the space or two after it.
    .PARAMETER Text
        The message. A blank one is replaced by a placeholder.
    .PARAMETER Marker
        What precedes the first line's text, trailing space included.
    .PARAMETER Color
        The foreground color of every line.
    .PARAMETER Indent
        Passed to Format-LineIndent.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory)]
        [string]$Marker,

        [Parameter(Mandatory)]
        [System.ConsoleColor]$Color,

        [int]$Indent = -1
    )

    Close-OpenLine
    $prefix = Format-LineIndent -Indent $Indent
    $message = Format-MessageText $Text
    Write-MessageLine -Lead "$prefix$Marker" -Continuation "$prefix   " -Text $message -Color $Color
}
