function Open-DoingLine {
    <#
    .SYNOPSIS
        Writes a "Doing" line and leaves it open for an outcome.
    .DESCRIPTION
        Not exported. The one place a Doing line is opened: it ends any line
        already open, writes the text in cyan behind a play marker and
        followed by " ...", and records the line as open, with where a later
        line of its outcome goes, for Complete-OpenLine. Each line gets a new
        number, which it returns, so a caller can later finish its own line
        and no other. A line the caller's information preference ignores is
        never written, so nothing is recorded as open.
    .PARAMETER Text
        What the step is attempting. A blank one is replaced by a placeholder.
    .OUTPUTS
        The line's number, or 0 when no line was opened.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    Close-OpenLine
    $prefix = Format-LineIndent
    $continuation = "$prefix  "
    $message = "$(Format-MessageText $Text) ..."
    $opened = 0
    if ($InformationPreference -ne 'Ignore') {
        # State before the write: under -InformationAction Stop the line is
        # printed before the error, so it is open even though the call fails.
        $script:LineNumber++
        $script:LineOpen = $true
        $script:OpenLineContinuation = $continuation
        $opened = $script:LineNumber
    }

    Write-MessageLine -Lead "${prefix}▶ " -Continuation $continuation `
        -Text $message -Color Cyan -NoNewline
    return $opened
}
