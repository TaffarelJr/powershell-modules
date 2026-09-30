function Test-FileFailed {
    <#
    .SYNOPSIS
        Reports whether a file's result should count as a failure of the run:
        a non-zero exit, a crash even at exit 0, or any case that failed
        even when the file exited 0.
    .DESCRIPTION
        The exit code and the tally are two reports of one outcome; either
        one saying "failed" is enough. A file that forgets to exit with its
        own result prints a failing tally and still exits 0.
    .PARAMETER Result
        One file's result, from Invoke-TestFileProcess.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result
    )

    return $Result.ExitCode -ne 0 -or $Result.Crashed -or $Result.Failed -gt 0
}
