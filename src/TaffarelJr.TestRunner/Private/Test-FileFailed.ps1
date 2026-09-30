function Test-FileFailed {
    <#
    .SYNOPSIS
        Reports whether a file's result should count as a failure of the run:
        a non-zero exit, or a crash even at exit 0.
    #>
    param([Parameter(Mandatory)][PSCustomObject]$Result)

    return $Result.ExitCode -ne 0 -or $Result.Crashed
}
