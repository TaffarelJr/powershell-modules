function Write-TestResult {
    <#
    .SYNOPSIS
        Prints one file's verdict and time,
        then its output when it failed or -ShowOutput asked for it.
    #>
    param(
        [Parameter(Mandatory)][PSCustomObject]$Result,
        [switch]$ShowOutput
    )

    $verdict = Format-TestVerdict -Result $Result
    $seconds = '{0,6:N1}s' -f $Result.Seconds
    $color = if ($Result.ExitCode -eq 0) { 'Green' } else { 'Red' }
    Write-Host " $verdict  $seconds" -ForegroundColor $color

    if (-not $ShowOutput -and $Result.ExitCode -eq 0) {
        return
    }

    foreach ($line in $Result.Output) {
        Write-Host "    $line"
    }
}
