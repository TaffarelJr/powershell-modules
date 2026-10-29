function Format-TestVerdict {
    <#
    .SYNOPSIS
        Renders one file's result the way the runner prints it.
    .DESCRIPTION
        A file no process ran says so instead of showing an exit code it never
        had; a skipped file shows the reason it gave; a file that ran no cases
        on purpose passes with a note saying its checks run by other means.
    .PARAMETER Result
        One file's result, from Invoke-TestFileProcess.
    .PARAMETER WithoutMarker
        Leaves out the emoji the text starts with, for a caller that prints
        its own marker in front of the line.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result,

        [switch]$WithoutMarker
    )

    $marker = '✅'
    $text = "$($Result.Passed) passed"
    if ($Result.NotStarted) {
        $marker = '💥'
        $text = 'not started'
    }
    elseif ($Result.TimedOut) {
        $marker = '⏱'
        $text = 'timed out'
    }
    elseif ($Result.Crashed) {
        $marker = '💥'
        $text = "crashed (exit $($Result.ExitCode))"
    }
    elseif ($Result.Skipped) {
        $marker = '⏭'
        $text = "skipped - $($Result.SkipReason)"
    }
    elseif ($Result.ExitCode -ne 0 -or $Result.Failed -gt 0) {
        $marker = '❌'
        $text = "$($Result.Passed) passed, $($Result.Failed) failed"
    }
    elseif ($Result.AllowedEmpty) {
        $text = "$($Result.Passed) passed (checks run by other means)"
    }

    if ($WithoutMarker) {
        return $text
    }

    return "$marker $text"
}
