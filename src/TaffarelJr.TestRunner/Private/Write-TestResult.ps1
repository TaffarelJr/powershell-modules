function Write-TestResult {
    <#
    .SYNOPSIS
        Prints one file's name, verdict and time on a line of its own, then
        its output when it failed or -ShowOutput asked for it.
    .DESCRIPTION
        The line is marked as TaffarelJr.ConsoleOutput marks a success, a
        failure, or a skip. A blank line of the output is left out: the
        console module prints a placeholder for text with nothing in it.
    .PARAMETER Result
        One file's result, from Invoke-TestFileProcess.
    .PARAMETER ShowOutput
        Prints the output of a passing file too.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Result,

        [switch]$ShowOutput
    )

    $failed = Test-FileFailed -Result $Result
    $verdict = Format-TestVerdict -Result $Result -WithoutMarker
    $seconds = [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0,6:N1}s', $Result.Seconds)
    $line = "$($Result.Name)  $verdict  $seconds"
    if ($failed) {
        Write-Failure $line
    }
    elseif ($Result.Skipped) {
        Write-Skip $line
    }
    else {
        Write-Success $line
    }

    if (-not $ShowOutput -and -not $failed) {
        return
    }

    foreach ($text in $Result.Output) {
        if (-not [string]::IsNullOrWhiteSpace($text)) {
            Write-Detail $text
        }
    }
}
