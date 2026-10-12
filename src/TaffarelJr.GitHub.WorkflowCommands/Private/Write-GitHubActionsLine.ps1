function Write-GitHubActionsLine {
    <#
    .SYNOPSIS
        Writes one line, as UTF-8, straight to the process's standard output,
        or to the host where that is not the step's log.
    .DESCRIPTION
        Not exported. Every workflow command goes through this one function.

        The runner reads workflow commands from the step's standard output
        and nowhere else. In the step's own console process, Write-Host
        would go through PowerShell's information stream, which a caller
        can silence or capture without meaning to (-InformationAction
        Ignore, 6>$null, *>&1) - and a lost add-mask lets a secret print in
        clear later. The console's own encoding is bypassed too: it may be
        a legacy code page that turns text outside ASCII into something
        else. Bypassing the host also keeps the line out of a
        Start-Transcript transcript. A thread job's add-mask written through
        the host would even print after the job's own output, the secret
        included.

        A thread job or ForEach-Object -Parallel block in that process
        writes raw too, with a line break in front, in the same write: the
        console host may be printing a line of the job's output at that
        moment, and writes the text and its line end separately, so a
        command without one could land after the text and go unseen. An
        occasional blank line is the cost.

        A process that is a PowerShell server - a background job, an
        out-of-process runspace, a remote session - gets Write-Host instead,
        in every runspace of it: its standard output carries the session,
        and a raw line there breaks it. Through the host, the line reaches
        the parent, which shows it - after the job's output, so mask a value
        in the step's own process before such a job prints it.

        The runner recognizes a command only at the start of a line, so a
        partial line printed before it (Write-Host -NoNewline) must be
        ended with a newline first, or the command is read as plain text.
    .PARAMETER Line
        The text to write. A line end is added.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSAvoidUsingWriteHost',
        '',
        Justification = 'Shows text to the person at the console; it is not data.')]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Line
    )

    $mode = Get-GitHubActionsOutputMode
    if ($mode -eq 'Host') {
        Write-Host $Line
        return
    }

    $text = $Line + [Environment]::NewLine
    if ($mode -eq 'Runspace') {
        $text = [Environment]::NewLine + $text
    }

    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($text)
    $stream = Open-GitHubActionsStandardOutput
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    }
    finally {
        $stream.Dispose()
    }
}
