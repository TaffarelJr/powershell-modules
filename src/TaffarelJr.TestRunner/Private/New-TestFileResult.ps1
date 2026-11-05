function New-TestFileResult {
    <#
    .SYNOPSIS
        Builds a test file's result, the one shape every consumer of a result
        (the printer, the summary, the pass/fail test) can rely on.
    .PARAMETER Name
        The file's display name.
    .PARAMETER Passed
        How many cases passed.
    .PARAMETER Failed
        How many cases failed.
    .PARAMETER Crashed
        The file did not finish in a way its tally can be trusted.
    .PARAMETER TimedOut
        The file was stopped for running too long.
    .PARAMETER NotStarted
        No process ran the file at all, so there is no exit code of its own;
        pass -Crashed with it.
    .PARAMETER Skipped
        The file said it was not running here, and why.
    .PARAMETER SkipReason
        The reason a skipped file gave.
    .PARAMETER AllowedEmpty
        The file ran no cases and said its checks run by other means.
    .PARAMETER ExitCode
        The file's exit code.
    .PARAMETER Seconds
        How long it ran.
    .PARAMETER Output
        What it printed, a line at a time.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Builds a result object in memory; nothing outside the process changes.')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [int]$Passed = 0,

        [int]$Failed = 0,

        [switch]$Crashed,

        [switch]$TimedOut,

        [switch]$NotStarted,

        [switch]$Skipped,

        [AllowEmptyString()]
        [string]$SkipReason = '',

        [switch]$AllowedEmpty,

        [int]$ExitCode = 0,

        [double]$Seconds = 0,

        [string[]]$Output = @()
    )

    return [PSCustomObject]@{
        Name         = $Name
        Passed       = $Passed
        Failed       = $Failed
        Crashed      = $Crashed.IsPresent
        TimedOut     = $TimedOut.IsPresent
        NotStarted   = $NotStarted.IsPresent
        Skipped      = $Skipped.IsPresent
        SkipReason   = $SkipReason
        AllowedEmpty = $AllowedEmpty.IsPresent
        ExitCode     = $ExitCode
        Seconds      = $Seconds
        Output       = $Output
    }
}
